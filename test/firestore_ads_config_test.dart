import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firestore Ads Config Sanity', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    test('RemoteConfigService loads real ad IDs from cached Firestore config and prioritizes them', () async {
      final flavorId = currentFlavor.name;
      final mockFirestoreData = {
        'showAds': true,
        'bannerAdUnitId': 'ca-app-pub-9999999999999999/1111111111',
        'interstitialAdUnitId': 'ca-app-pub-9999999999999999/2222222222',
        'rewardedAdUnitId': 'ca-app-pub-9999999999999999/3333333333',
        'appOpenAdUnitId': 'ca-app-pub-9999999999999999/4444444444',
        'rewardedInterstitialAdUnitId': 'ca-app-pub-9999999999999999/5555555555',
        'nativeAdUnitId': 'ca-app-pub-9999999999999999/6666666666',
        'interstitialCooldownS': 45,
        'interstitialMinSessionS': 60,
        'appOpenCooldownS': 7200,
      };

      // Store mock Firestore snapshot in local storage cache
      storage.setString(
        'cached_ads_config_$flavorId',
        jsonEncode(mockFirestoreData),
      );

      final rcService = RemoteConfigService();
      rcService.attachStorage(storage);

      // Verify that all ad getters prioritize Firestore real IDs over defaults
      expect(rcService.showAds, isTrue);
      expect(rcService.bannerAdUnitId, 'ca-app-pub-9999999999999999/1111111111');
      expect(rcService.interstitialAdUnitId, 'ca-app-pub-9999999999999999/2222222222');
      expect(rcService.rewardedAdUnitId, 'ca-app-pub-9999999999999999/3333333333');
      expect(rcService.appOpenAdUnitId, 'ca-app-pub-9999999999999999/4444444444');
      expect(rcService.rewardedInterstitialAdUnitId, 'ca-app-pub-9999999999999999/5555555555');
      expect(rcService.nativeAdUnitId, 'ca-app-pub-9999999999999999/6666666666');

      // Verify ad pacing overrides from Firestore
      expect(rcService.interstitialCooldownSeconds, 45);
      expect(rcService.interstitialMinSessionSeconds, 60);
      expect(rcService.appOpenCooldownSeconds, 7200);
    });

    test('RemoteConfigService falls back safely when Firestore config has empty or missing values', () async {
      final flavorId = currentFlavor.name;
      final emptyFirestoreData = {
        'showAds': false,
        'bannerAdUnitId': '   ',
        'interstitialAdUnitId': '',
        'rewardedAdUnitId': null,
      };

      storage.setString(
        'cached_ads_config_$flavorId',
        jsonEncode(emptyFirestoreData),
      );

      final rcService = RemoteConfigService();
      rcService.attachStorage(storage);

      expect(rcService.showAds, isFalse);
      // Empty/null units shouldn't be returned as IDs; they must resolve to fallback
      expect(rcService.bannerAdUnitId.trim().isNotEmpty, isTrue);
      expect(rcService.bannerAdUnitId.trim(), isNot(''));
      expect(rcService.interstitialAdUnitId.trim().isNotEmpty, isTrue);
      expect(rcService.rewardedAdUnitId.trim().isNotEmpty, isTrue);
    });

    test('Ad Unit ID sanitization strips quotes/semicolons and rejects App IDs', () async {
      final flavorId = currentFlavor.name;
      final malformedFirestoreData = {
        // Trailing semicolon and quotes should be sanitized cleanly
        'bannerAdUnitId': '"ca-app-pub-7469053965996793/7432465476";',
        // App ID with ~ instead of / should be rejected and fall back
        'interstitialAdUnitId': 'ca-app-pub-7469053965996793~5561725467',
      };

      storage.setString(
        'cached_ads_config_$flavorId',
        jsonEncode(malformedFirestoreData),
      );

      final rcService = RemoteConfigService();
      rcService.attachStorage(storage);

      // Sanitized correctly:
      expect(rcService.bannerAdUnitId, 'ca-app-pub-7469053965996793/7432465476');

      // Rejected App ID with ~ and used safe fallback:
      expect(rcService.interstitialAdUnitId, isNot(contains('~')));
      expect(rcService.interstitialAdUnitId, contains('/'));
    });

    test('Ads listeners can be registered and notified', () async {
      final rcService = RemoteConfigService();
      int callCount = 0;
      void listener() => callCount++;

      rcService.addAdsListener(listener);
      // Simulating config change notification by calling attachStorage
      rcService.attachStorage(storage);
      expect(callCount, 0);

      // Unsubscribe
      rcService.removeAdsListener(listener);
    });

    test('getAdsDiagnostics returns complete structured status', () async {
      final rcService = RemoteConfigService();
      final diag = rcService.getAdsDiagnostics();

      expect(diag.containsKey('flavor'), isTrue);
      expect(diag.containsKey('showAds'), isTrue);
      expect(diag.containsKey('bannerAdUnitId'), isTrue);
      expect(diag.containsKey('bannerSource'), isTrue);
      expect(diag.containsKey('interstitialAdUnitId'), isTrue);
      expect(diag.containsKey('interstitialSource'), isTrue);
      expect(diag.containsKey('interstitialCooldownS'), isTrue);

      // Verify logAdsDiagnostics runs without throwing
      expect(() => rcService.logAdsDiagnostics(), returnsNormally);
    });
  });
}
