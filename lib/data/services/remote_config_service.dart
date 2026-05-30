import 'dart:developer' as developer;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:pixel_art_app/config/app_config.dart';

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
        'pixelyart_show_ads': false,
        'pixelyart_banner_ad_unit_id': 'ca-app-pub-3940256099942544/6300978111',
        'pixelyart_interstitial_ad_unit_id': 'ca-app-pub-3940256099942544/1033173712',
        'pixelyart_rewarded_ad_unit_id': 'ca-app-pub-3940256099942544/5224354917',
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

  // Getters for dynamic configurations
  bool get showAds => _remoteConfig.getBool('pixelyart_show_ads');
  
  String get bannerAdUnitId {
    final id = _remoteConfig.getString('pixelyart_banner_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-3940256099942544/6300978111';
  }

  String get interstitialAdUnitId {
    final id = _remoteConfig.getString('pixelyart_interstitial_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-3940256099942544/1033173712';
  }

  String get rewardedAdUnitId {
    final id = _remoteConfig.getString('pixelyart_rewarded_ad_unit_id');
    return id.isNotEmpty ? id : 'ca-app-pub-3940256099942544/5224354917';
  }
}
