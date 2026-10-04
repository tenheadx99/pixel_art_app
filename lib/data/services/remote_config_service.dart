import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixel_art_app/data/services/economy_config_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/config/flavor.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._();

  FirebaseRemoteConfig? _rcInstance;
  FirebaseRemoteConfig get _remoteConfig =>
      _rcInstance ??= FirebaseRemoteConfig.instance;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  LocalStorageService? _storage;
  Map<String, dynamic> _firestoreAdsConfig = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreAdsSubscription;

  void attachStorage(LocalStorageService storage) {
    _storage = storage;
    _loadCachedFirestoreConfig();
  }

  void _loadCachedFirestoreConfig() {
    try {
      final flavorId = currentFlavor.name;
      final cachedJson = _storage?.getString('cached_ads_config_$flavorId');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map<String, dynamic>) {
          _firestoreAdsConfig = Map<String, dynamic>.from(decoded);
          developer.log('Loaded cached admin ads config for $flavorId', name: 'AdsConfig');
        }
      }
    } catch (e) {
      developer.log('Error reading cached admin ads config', name: 'AdsConfig', error: e);
    }
  }

  void _saveCachedFirestoreConfig() {
    try {
      final flavorId = currentFlavor.name;
      final jsonStr = jsonEncode(_firestoreAdsConfig);
      _storage?.setString('cached_ads_config_$flavorId', jsonStr);
    } catch (_) {}
  }

  Future<void> _syncFirestoreAdsConfig() async {
    final flavorId = currentFlavor.name;
    final docPath = 'pixel_art/$flavorId/config/ads';

    // 1. Initial one-time fetch
    try {
      final snap = await _firestore.doc(docPath).get();
      if (snap.exists && snap.data() != null) {
        _firestoreAdsConfig = Map<String, dynamic>.from(snap.data()!);
        _saveCachedFirestoreConfig();
        AppConfig.showAds = showAds;
        developer.log(
          'Admin Firestore ads config synced for $flavorId (banner: ${_firestoreAdsConfig['bannerAdUnitId']}, showAds: ${_firestoreAdsConfig['showAds']})',
          name: 'AdsConfig',
        );
      } else {
        developer.log('No admin ads config doc found at $docPath, using defaults', name: 'AdsConfig');
      }
    } catch (e) {
      developer.log('Failed to fetch admin ads config from Firestore ($docPath)', error: e, name: 'AdsConfig');
    }

    // 2. Real-time stream listener (so admin app saves reflect immediately)
    try {
      await _firestoreAdsSubscription?.cancel();
      _firestoreAdsSubscription = _firestore
          .doc(docPath)
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          _firestoreAdsConfig = Map<String, dynamic>.from(snap.data()!);
          _saveCachedFirestoreConfig();
          AppConfig.showAds = showAds;
          developer.log('Realtime admin ads config updated for $flavorId', name: 'AdsConfig');
        }
      }, onError: (e) {
        developer.log('Admin ads config realtime stream error', error: e, name: 'AdsConfig');
      });
    } catch (e) {
      developer.log('Failed to attach admin ads config realtime stream', error: e, name: 'AdsConfig');
    }
  }

  String? _getFirestoreString(String key) {
    final val = _firestoreAdsConfig[key];
    if (val is String && val.trim().isNotEmpty) {
      return val.trim();
    }
    return null;
  }

  void Function(String updateUrl)? onForceUpdateTriggered;

  Future<void> initialize() async {
    // 1. Sync ads configuration from Admin App (Firestore: pixel_art/{flavor}/config/ads)
    await _syncFirestoreAdsConfig();

    try {
      // Set Remote Config settings (0s in debug for instant testing, 5m in production)
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 5),
      ));

      // Listen for real-time Remote Config updates published from Firebase Console
      _remoteConfig.onConfigUpdated.listen(
        (event) async {
          try {
            await _remoteConfig.activate();
            AppConfig.showAds = showAds;
            developer.log('Remote Config updated in real-time!', name: 'RemoteConfig');
            _checkForceUpdateRealtime();
          } catch (e, stackTrace) {
            developer.log(
              'Failed to activate real-time Remote Config update',
              name: 'RemoteConfig',
              error: e,
              stackTrace: stackTrace,
            );
          }
        },
        onError: (error, stackTrace) {
          developer.log(
            'Remote Config real-time stream connection error (continuing offline)',
            name: 'RemoteConfig',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );

      // Set defaults for Remote Config
      await _remoteConfig.setDefaults(<String, dynamic>{
        'pixelyart_show_ads': true,
        'pixelyart_banner_ad_unit_id': 'ca-app-pub-9064606616675657/7511066180',
        'pixelyart_interstitial_ad_unit_id': 'ca-app-pub-9064606616675657/6197984517',
        'pixelyart_rewarded_ad_unit_id': 'ca-app-pub-9064606616675657/4884902843',
        'pixelyart_app_open_ad_unit_id': 'ca-app-pub-9064606616675657/4258216888',
        'pixelyart_min_version': '1.0.0',
        'pixelyart_force_update_url': '',
        // Ad pacing — tune from the console without a release.
        'pixelyart_interstitial_cooldown_s': 90,
        'pixelyart_interstitial_min_session_s': 120,
        'pixelyart_interstitial_max_per_session': 4,
        'pixelyart_interstitial_max_per_day': 12,
        'pixelyart_interstitial_post_rewarded_s': 60,
        'pixelyart_interstitial_min_progress_pct': 25,
        'pixelyart_app_open_cooldown_s': 14400,
        // Collapsible bottom banner (typical 15-30% eCPM lift); bool so it
        // can be killed or A/B-tested from the console.
        'pixelyart_banner_collapsible': true,
        // Rewarded interstitial at the "next artwork" transition. Disabled
        // until an ad unit id is set here (create a *rewarded interstitial*
        // unit in AdMob first — the plain rewarded unit will not serve).
        'pixelyart_rewarded_interstitial_ad_unit_id': '',
        'pixelyart_next_art_reward_diamonds': 20,
        // Native ads in the home grid. Disabled until a *native advanced*
        // ad unit id is set here.
        'pixelyart_native_ad_unit_id': '',
        'pixelyart_home_native_ads_enabled': true,
        // Free-diamond rewarded placements (shop tile, home pill, streak
        // bonus) — amounts and caps tunable per flavor from the console.
        'pixelyart_free_diamonds_enabled': true,
        'pixelyart_rewarded_diamonds_amount': 25,
        'pixelyart_rewarded_diamonds_daily_cap': 5,
        'pixelyart_premium_artworks_enabled': true,
        'pixelyart_diamond_cost_unlock_art': 100,
        'pixelyart_plus_1day_product_id': 'pixel_art_plus_1day',
        'pixelyart_plus_weekly_product_id': 'pixel_art_plus_weekly',
        'pixelyart_plus_monthly_product_id': 'pixel_art_plus_monthly',
        'pixelyart_plus_yearly_product_id': 'pixel_art_plus_yearly',
        'pixelyart_remove_ads_product_id': 'pixel_art_remove_ads',

        'pixelyart_plus_1day_price': '\$0.99 / day',
        'pixelyart_plus_weekly_price': '\$2.99 / wk',
        'pixelyart_plus_monthly_price': '\$7.99 / mo',
        'pixelyart_plus_yearly_price': '\$29.99 / yr',
        'pixelyart_remove_ads_price': '\$4.99',
        'pixelyart_lifetime_pro_price': '\$19.99',

        'pixelyart_plus_1day_offer': '24-Hour Pass',
        'pixelyart_plus_weekly_offer': '7 Days Free Trial',
        'pixelyart_plus_monthly_offer': 'Most Popular',
        'pixelyart_plus_yearly_offer': 'Save 65% Best Value',
        'pixelyart_remove_ads_offer': 'One-Time Purchase',
        // Flavor-specific show_ads defaults. All flavors monetize with ads;
        // PixelCalm is limited to banner + rewarded via
        // FlavorConfig.fullScreenAdsEnabled (no interstitial/app-open there).
        // Any of these can still be killed per-flavor from the Firebase
        // console without a release.
        'devotional_show_ads': true,
        'anime_show_ads': true,
        'pixelcalm_show_ads': true,
        'diamond_show_ads': true,
        'bible_show_ads': true,
        'stitch_show_ads': true,
      });

      // Fetch and activate config parameters
      bool updated = await _remoteConfig.fetchAndActivate();
      developer.log('Remote Config fetchAndActivate completed. Status updated: $updated');

      // Update AppConfig with remote config values
      AppConfig.showAds = showAds;
      developer.log('Remote Config values: showAds = $showAds, banner = $bannerAdUnitId');
    } catch (e, stackTrace) {
      developer.log('Failed to initialize/fetch Remote Config. Using defaults.', error: e, stackTrace: stackTrace);
      // Fallback
      AppConfig.showAds = showAds;
    }
  }

  String _getFlavorKey(String baseKey) {
    return FlavorConfig.getFlavorKey(currentFlavor, baseKey);
  }

  bool _getBool(String baseKey) {
    final flavorKey = _getFlavorKey(baseKey);
    if (_remoteConfig.getAll().containsKey(flavorKey)) {
      return _remoteConfig.getBool(flavorKey);
    }
    return _remoteConfig.getBool('pixelyart_$baseKey');
  }

  String _getString(String baseKey) {
    try {
      final flavorKey = _getFlavorKey(baseKey);
      if (_remoteConfig.getAll().containsKey(flavorKey)) {
        final value = _remoteConfig.getString(flavorKey);
        if (value.isNotEmpty) return value;
      }
      return _remoteConfig.getString('pixelyart_$baseKey');
    } catch (_) {
      return '';
    }
  }

  int _getInt(String baseKey, int fallback) {
    try {
      final flavorKey = _getFlavorKey(baseKey);
      if (_remoteConfig.getAll().containsKey(flavorKey)) {
        final v = _remoteConfig.getInt(flavorKey);
        if (v > 0) return v;
      }
      final defaultVal = _remoteConfig.getInt('pixelyart_$baseKey');
      return defaultVal > 0 ? defaultVal : fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Getters for dynamic configurations: Admin App (Firestore) -> Remote Config -> Local defaults
  bool get showAds {
    final fsShow = _firestoreAdsConfig['showAds'];
    if (fsShow is bool) return fsShow;
    return _getBool('show_ads');
  }
  
  String get minRequiredVersion {
    final version = _getString('min_version');
    return version.isNotEmpty ? version : '1.0.0';
  }

  String get forceUpdateUrl => _getString('force_update_url');

  /// Resolves an ad unit ID with strict flavor isolation:
  /// - [AppFlavor.original]: checks Remote Config `pixelyart_<key>`, falling back to production unit.
  /// - Other flavors (e.g. stitch, devotional, anime): checks Remote Config `<flavor>_<key>`.
  ///   If the flavor has its own real ID configured (not matching the original app's ID), it is used.
  ///   NEVER falls back to Pixely's production real ad unit IDs! If unconfigured, safely returns
  ///   the official Google AdMob test ad unit ID.
  String _getAdUnitId({
    required String baseKey,
    required String productionFallback,
    required String testUnitIdAndroid,
    required String testUnitIdIos,
  }) {
    final isIos = !kIsWeb && Platform.isIOS;
    final testUnitId = isIos ? testUnitIdIos : testUnitIdAndroid;

    try {
      if (currentFlavor == AppFlavor.original) {
        final flavorKey = _getFlavorKey(baseKey);
        if (_remoteConfig.getAll().containsKey(flavorKey)) {
          final val = _remoteConfig.getString(flavorKey);
          if (val.isNotEmpty) return val;
        }
        final defaultVal = _remoteConfig.getString('pixelyart_$baseKey');
        if (defaultVal.isNotEmpty) return defaultVal;
        return productionFallback;
      }

      // Non-original flavors (stitch, devotional, anime, pixelcalm, diamond, bible):
      final flavorKey = _getFlavorKey(baseKey);
      if (_remoteConfig.getAll().containsKey(flavorKey)) {
        final val = _remoteConfig.getString(flavorKey);
        // Only use the flavor's ID if non-empty and not accidentally pointing to Pixely's ID
        if (val.isNotEmpty && val != productionFallback) {
          return val;
        }
      }

      // Safe fallback: never use Pixely real ad IDs on other flavors!
      return testUnitId;
    } catch (_) {
      return currentFlavor == AppFlavor.original ? productionFallback : testUnitId;
    }
  }
  
  String get bannerAdUnitId {
    final fsId = _getFirestoreString('bannerAdUnitId');
    if (fsId != null) return fsId;

    return _getAdUnitId(
      baseKey: 'banner_ad_unit_id',
      productionFallback: AppConstants.bannerAdUnitId,
      testUnitIdAndroid: AppConstants.testBannerAdUnitIdAndroid,
      testUnitIdIos: AppConstants.testBannerAdUnitIdIos,
    );
  }

  String get interstitialAdUnitId {
    final fsId = _getFirestoreString('interstitialAdUnitId');
    if (fsId != null) return fsId;

    return _getAdUnitId(
      baseKey: 'interstitial_ad_unit_id',
      productionFallback: AppConstants.interstitialAdUnitId,
      testUnitIdAndroid: AppConstants.testInterstitialAdUnitIdAndroid,
      testUnitIdIos: AppConstants.testInterstitialAdUnitIdIos,
    );
  }

  String get rewardedAdUnitId {
    final fsId = _getFirestoreString('rewardedAdUnitId');
    if (fsId != null) return fsId;

    return _getAdUnitId(
      baseKey: 'rewarded_ad_unit_id',
      productionFallback: AppConstants.rewardedAdUnitId,
      testUnitIdAndroid: AppConstants.testRewardedAdUnitIdAndroid,
      testUnitIdIos: AppConstants.testRewardedAdUnitIdIos,
    );
  }

  String get appOpenAdUnitId {
    final fsId = _getFirestoreString('appOpenAdUnitId');
    if (fsId != null) return fsId;

    return _getAdUnitId(
      baseKey: 'app_open_ad_unit_id',
      productionFallback: AppConstants.appOpenAdUnitId,
      testUnitIdAndroid: AppConstants.testAppOpenAdUnitIdAndroid,
      testUnitIdIos: AppConstants.testAppOpenAdUnitIdIos,
    );
  }

  /// Minimum gap between two interstitials.
  int get interstitialCooldownSeconds {
    final fsVal = _firestoreAdsConfig['interstitialCooldownS'];
    if (fsVal is int && fsVal > 0) return fsVal;
    return _getInt('interstitial_cooldown_s', 90);
  }

  /// Coloring sessions shorter than this never trigger an exit interstitial.
  int get interstitialMinSessionSeconds {
    final fsVal = _firestoreAdsConfig['interstitialMinSessionS'];
    if (fsVal is int && fsVal > 0) return fsVal;
    return _getInt('interstitial_min_session_s', 120);
  }

  /// Hard ceiling on interstitials in one app session. The cooldown alone
  /// lets a long session serve 20+; this caps the total.
  int get interstitialMaxPerSession =>
      _getInt('interstitial_max_per_session', 4);

  /// Hard ceiling on interstitials per calendar day, across sessions.
  int get interstitialMaxPerDay => _getInt('interstitial_max_per_day', 12);

  /// Suppression window after a rewarded ad — an interstitial right on the
  /// heels of a rewarded feels like a double-charge.
  int get interstitialPostRewardedSeconds =>
      _getInt('interstitial_post_rewarded_s', 60);

  /// A session that reached this much artwork progress may see an exit
  /// interstitial even below the min-session length (a user who coloured a
  /// quarter of a piece in 110s is not a drive-by).
  int get interstitialMinProgressPct =>
      _getInt('interstitial_min_progress_pct', 25);

  /// Minimum gap between two app-open ads.
  int get appOpenCooldownSeconds {
    final fsVal = _firestoreAdsConfig['appOpenCooldownS'];
    if (fsVal is int && fsVal > 0) return fsVal;
    return _getInt('app_open_cooldown_s', 14400);
  }

  /// Whether banners request the collapsible-bottom variant.
  bool get bannerCollapsibleEnabled => _getBool('banner_collapsible');

  /// Rewarded-interstitial unit for the "next artwork" moment.
  /// Priority: Admin App (Firestore) -> Flavor-specific Remote Config -> Pixely (original only) -> Empty
  String get rewardedInterstitialAdUnitId {
    final fsId = _getFirestoreString('rewardedInterstitialAdUnitId');
    if (fsId != null) return fsId;

    try {
      final flavorKey = _getFlavorKey('rewarded_interstitial_ad_unit_id');
      if (_remoteConfig.getAll().containsKey(flavorKey)) {
        final val = _remoteConfig.getString(flavorKey);
        if (val.isNotEmpty) return val;
      }
      if (currentFlavor == AppFlavor.original) {
        return _remoteConfig.getString('pixelyart_rewarded_interstitial_ad_unit_id');
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Diamonds granted for watching the "next artwork" rewarded interstitial.
  int get nextArtRewardDiamonds => _getInt('next_art_reward_diamonds', 20);

  /// Native-advanced unit for the home grid.
  /// Priority: Admin App (Firestore) -> Flavor-specific Remote Config -> Pixely (original only) -> Empty
  String get nativeAdUnitId {
    final fsId = _getFirestoreString('nativeAdUnitId');
    if (fsId != null) return fsId;

    try {
      final flavorKey = _getFlavorKey('native_ad_unit_id');
      if (_remoteConfig.getAll().containsKey(flavorKey)) {
        final val = _remoteConfig.getString(flavorKey);
        if (val.isNotEmpty) return val;
      }
      if (currentFlavor == AppFlavor.original) {
        return _remoteConfig.getString('pixelyart_native_ad_unit_id');
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Kill switch for home-grid native ads (unit id must also be set).
  bool get homeNativeAdsEnabled => _getBool('home_native_ads_enabled');

  // --- Free-diamond rewarded placements ---

  /// Kill switch for the diamond-earning rewarded placements. A bool because
  /// [_getInt] treats 0 as "unset" and can't express "off".
  bool get freeDiamondsEnabled => _getBool('free_diamonds_enabled');

  /// Diamonds granted per capped free-diamond claim (shop tile + home pill).
  int get rewardedDiamondsAmount => _getInt('rewarded_diamonds_amount', 25);

  /// Shared daily cap across the shop tile and home pill.
  int get rewardedDiamondsDailyCap =>
      _getInt('rewarded_diamonds_daily_cap', 5);

  /// Diamonds for the once-a-day streak bonus claim on the daily banner.
  int get dailyStreakAdBonus => _getInt('daily_streak_ad_bonus', 30);

  // --- Dynamic Premium Artworks & Subscription Product IDs ---

  /// Global toggle to enable/disable premium artwork & VIP subscriptions dynamically from Admin Firestore config.
  bool get premiumArtworksEnabled => EconomyConfigService().isVipSubscriptionEnabled;

  String get plus1DayProductId {
    final id = _getString('plus_1day_product_id');
    return id.isNotEmpty ? id : AppConstants.plus1DayProductId;
  }

  String get plusWeeklyProductId {
    final id = _getString('plus_weekly_product_id');
    return id.isNotEmpty ? id : AppConstants.plusWeeklyProductId;
  }

  String get plusMonthlyProductId {
    final id = _getString('plus_monthly_product_id');
    return id.isNotEmpty ? id : AppConstants.plusMonthlyProductId;
  }

  String get plusYearlyProductId {
    final id = _getString('plus_yearly_product_id');
    return id.isNotEmpty ? id : AppConstants.plusYearlyProductId;
  }

  String get removeAdsProductId {
    final id = _getString('remove_ads_product_id');
    return id.isNotEmpty ? id : AppConstants.removeAdsProductId;
  }

  // --- Dynamic Fallback Prices & Offer Badges ---

  String get plus1DayFallbackPrice {
    final p = _getString('plus_1day_price');
    return p.isNotEmpty ? p : '\$0.99 / day';
  }

  String get plusWeeklyFallbackPrice {
    final p = _getString('plus_weekly_price');
    return p.isNotEmpty ? p : '\$2.99 / wk';
  }

  String get plusMonthlyFallbackPrice {
    final p = _getString('plus_monthly_price');
    return p.isNotEmpty ? p : '\$7.99 / mo';
  }

  String get plusYearlyFallbackPrice {
    final p = _getString('plus_yearly_price');
    return p.isNotEmpty ? p : '\$29.99 / yr';
  }

  String get removeAdsFallbackPrice {
    final p = _getString('remove_ads_price');
    return p.isNotEmpty ? p : '\$4.99';
  }

  String get lifetimeProFallbackPrice {
    final p = _getString('lifetime_pro_price');
    return p.isNotEmpty ? p : '\$19.99';
  }

  String get plus1DayOfferText {
    final o = _getString('plus_1day_offer');
    return o.isNotEmpty ? o : '24-Hour Pass';
  }

  String get plusWeeklyOfferText {
    final o = _getString('plus_weekly_offer');
    return o.isNotEmpty ? o : '7 Days Free Trial';
  }

  String get plusMonthlyOfferText {
    final o = _getString('plus_monthly_offer');
    return o.isNotEmpty ? o : 'Most Popular';
  }

  String get plusYearlyOfferText {
    final o = _getString('plus_yearly_offer');
    return o.isNotEmpty ? o : 'Save 65% Best Value';
  }

  String get removeAdsOfferText {
    final o = _getString('remove_ads_offer');
    return o.isNotEmpty ? o : 'One-Time Purchase';
  }

  /// Cost in diamonds to permanently unlock a single premium artwork.
  int get diamondCostUnlockArt =>
      _getInt('diamond_cost_unlock_art', AppConstants.diamondCostUnlockArt);

  Future<void> _checkForceUpdateRealtime() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final minVersion = minRequiredVersion;
      if (_isVersionOlder(currentVersion, minVersion)) {
        onForceUpdateTriggered?.call(forceUpdateUrl);
      }
    } catch (e) {
      developer.log('Realtime force update check error', error: e);
    }
  }

  static bool _isVersionOlder(String current, String required) {
    final currentClean = current.split('+')[0];
    final requiredClean = required.split('+')[0];

    final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final requiredParts = requiredClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (requiredParts.length < 3) {
      requiredParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < requiredParts[i]) return true;
      if (currentParts[i] > requiredParts[i]) return false;
    }
    return false;
  }
}
