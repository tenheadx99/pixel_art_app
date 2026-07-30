import 'dart:developer' as developer;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/flavor.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      // Set Remote Config settings (low fetch interval for debugging/development)
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

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
        'pixelyart_daily_streak_ad_bonus': 30,
        // Flavor-specific show_ads defaults. All flavors monetize with ads;
        // PixelCalm is limited to banner + rewarded via
        // FlavorConfig.fullScreenAdsEnabled (no interstitial/app-open there).
        // Any of these can still be killed per-flavor from the Firebase
        // console without a release.
        'devotional_show_ads': true,
        'anime_show_ads': true,
        'pixelcalm_show_ads': true,
        'diamond_show_ads': true,
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
}
