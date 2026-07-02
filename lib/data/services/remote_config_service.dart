import 'dart:developer' as developer;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/services/firestore_config_service.dart';

/// Facade over the app's remote-tunable values. Resolution order for every
/// getter: Firestore admin override → Remote Config → hardcoded default.
/// (FirestoreConfigService.initialize() must run before [initialize] so the
/// overrides are in place when AppConfig.showAds is derived.)
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirestoreConfigService _firestoreConfig = FirestoreConfigService();

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
        // Flavor-specific show_ads defaults
        'devotional_show_ads': false,
        'anime_show_ads': false,
        'pixelcalm_show_ads': false,
        'diamond_show_ads': false,
      });

      // Fetch and activate config parameters
      bool updated = await _remoteConfig.fetchAndActivate();
      developer.log('Remote Config fetchAndActivate completed. Status updated: $updated');

      // Update AppConfig with remote config values, and keep it live when
      // the admin changes the Firestore ads config mid-session.
      AppConfig.showAds = showAds;
      _firestoreConfig.onChanged = () => AppConfig.showAds = showAds;
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

  // Getters for dynamic configurations. Firestore admin override wins, then
  // Remote Config, then the hardcoded default.
  bool get showAds => _firestoreConfig.showAds ?? _getBool('show_ads');

  String get minRequiredVersion {
    final override = _firestoreConfig.minVersion;
    if (override != null) return override;
    final version = _getString('min_version');
    return version.isNotEmpty ? version : '1.0.0';
  }

  String get forceUpdateUrl =>
      _firestoreConfig.forceUpdateUrl ?? _getString('force_update_url');

  // Ad unit IDs: resolved from Firestore/Remote Config, with the production
  // unit as local fallback when neither has fetched / has no value.
  String get bannerAdUnitId {
    final id = _firestoreConfig.bannerAdUnitId ??
        _getString('banner_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/7511066180';
  }

  String get interstitialAdUnitId {
    final id = _firestoreConfig.interstitialAdUnitId ??
        _getString('interstitial_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/6197984517';
  }

  String get rewardedAdUnitId {
    final id = _firestoreConfig.rewardedAdUnitId ??
        _getString('rewarded_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/4884902843';
  }

  String get appOpenAdUnitId {
    final id = _firestoreConfig.appOpenAdUnitId ??
        _getString('app_open_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-9064606616675657/4258216888';
  }

  /// Minimum gap between two interstitials.
  int get interstitialCooldownSeconds =>
      _firestoreConfig.interstitialCooldownS ??
      _getInt('interstitial_cooldown_s', 90);

  /// Coloring sessions shorter than this never trigger an exit interstitial.
  int get interstitialMinSessionSeconds =>
      _firestoreConfig.interstitialMinSessionS ??
      _getInt('interstitial_min_session_s', 120);

  /// Minimum gap between two app-open ads.
  int get appOpenCooldownSeconds =>
      _firestoreConfig.appOpenCooldownS ??
      _getInt('app_open_cooldown_s', 14400);
}
