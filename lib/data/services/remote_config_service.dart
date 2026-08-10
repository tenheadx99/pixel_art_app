import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/config/flavor.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  void Function(String updateUrl)? onForceUpdateTriggered;

  Future<void> initialize() async {
    try {
      // Set Remote Config settings (0s in debug for instant testing, 5m in production)
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 5),
      ));

      // Listen for real-time Remote Config updates published from Firebase Console
      _remoteConfig.onConfigUpdated.listen((event) async {
        await _remoteConfig.activate();
        AppConfig.showAds = showAds;
        developer.log('Remote Config updated in real-time!', name: 'RemoteConfig');
        _checkForceUpdateRealtime();
      });

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
        'pixelyart_app_open_cooldown_s': 14400,
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
    final flavorKey = _getFlavorKey(baseKey);
    if (_remoteConfig.getAll().containsKey(flavorKey)) {
      final value = _remoteConfig.getString(flavorKey);
      if (value.isNotEmpty) return value;
    }
    return _remoteConfig.getString('pixelyart_$baseKey');
  }

  int _getInt(String baseKey, int fallback) {
    final flavorKey = _getFlavorKey(baseKey);
    if (_remoteConfig.getAll().containsKey(flavorKey)) {
      final v = _remoteConfig.getInt(flavorKey);
      if (v > 0) return v;
    }
    final defaultVal = _remoteConfig.getInt('pixelyart_$baseKey');
    return defaultVal > 0 ? defaultVal : fallback;
  }

  // Getters for dynamic configurations
  bool get showAds => _getBool('show_ads');
  
  String get minRequiredVersion {
    final version = _getString('min_version');
    return version.isNotEmpty ? version : '1.0.0';
  }

  String get forceUpdateUrl => _getString('force_update_url');

  // Ad unit IDs: resolved from Remote Config, with the production unit as
  // local fallback when Remote Config has not yet fetched or has no value.
  String get bannerAdUnitId {
    final id = _getString('banner_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/7511066180';
  }

  String get interstitialAdUnitId {
    final id = _getString('interstitial_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/6197984517';
  }

  String get rewardedAdUnitId {
    final id = _getString('rewarded_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/4884902843';
  }

  String get appOpenAdUnitId {
    final id = _getString('app_open_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/4258216888';
  }

  /// Minimum gap between two interstitials.
  int get interstitialCooldownSeconds =>
      _getInt('interstitial_cooldown_s', 90);

  /// Coloring sessions shorter than this never trigger an exit interstitial.
  int get interstitialMinSessionSeconds =>
      _getInt('interstitial_min_session_s', 120);

  /// Minimum gap between two app-open ads.
  int get appOpenCooldownSeconds =>
      _getInt('app_open_cooldown_s', 14400);

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

  /// Global toggle to enable/disable premium artwork enforcement dynamically from Admin/Remote Config.
  bool get premiumArtworksEnabled => _getBool('premium_artworks_enabled');

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
