import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flavor Ads Configuration Verification', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
    });

    tearDown(() {
      setFlavorForTesting(null);
    });

    test('Pixely (original) flavor has ads enabled by default', () {
      final config = FlavorConfig.of(AppFlavor.original);
      expect(config.adsEnabled, isTrue, reason: 'Pixely flavor must have adsEnabled: true');
      expect(config.fullScreenAdsEnabled, isTrue);
      expect(config.bannerAdsEnabled, isTrue);

      setFlavorForTesting(AppFlavor.original);
      AppConfig.disableAds = !config.adsEnabled;
      expect(AppConfig.disableAds, isFalse);
    });

    test('Devotional (divine) flavor has ads enabled by default', () {
      final config = FlavorConfig.of(AppFlavor.devotional);
      expect(config.adsEnabled, isTrue, reason: 'Devotional/Divine flavor must have adsEnabled: true');
      expect(config.fullScreenAdsEnabled, isTrue);
      expect(config.bannerAdsEnabled, isTrue);

      setFlavorForTesting(AppFlavor.devotional);
      AppConfig.disableAds = !config.adsEnabled;
      expect(AppConfig.disableAds, isFalse);
    });

    test('PixelCalm (clam) flavor has ads enabled in rewarded-only mode', () {
      final config = FlavorConfig.of(AppFlavor.pixelcalm);
      expect(config.adsEnabled, isTrue, reason: 'PixelCalm flavor must have adsEnabled: true for rewarded ads');
      expect(config.fullScreenAdsEnabled, isFalse, reason: 'PixelCalm blocks interstitials/app-open');
      expect(config.bannerAdsEnabled, isFalse, reason: 'PixelCalm blocks banners');

      setFlavorForTesting(AppFlavor.pixelcalm);
      AppConfig.disableAds = !config.adsEnabled;
      AppConfig.disableFullScreenAds = !config.fullScreenAdsEnabled;
      AppConfig.disableBannerAds = !config.bannerAdsEnabled;

      expect(AppConfig.disableAds, isFalse);
      expect(AppConfig.disableFullScreenAds, isTrue);
      expect(AppConfig.disableBannerAds, isTrue);
    });

    test('Bible flavor has ads enabled by default', () {
      final config = FlavorConfig.of(AppFlavor.bible);
      expect(config.adsEnabled, isTrue, reason: 'Bible flavor must have adsEnabled: true');
      expect(config.fullScreenAdsEnabled, isTrue);
      expect(config.bannerAdsEnabled, isTrue);

      setFlavorForTesting(AppFlavor.bible);
      AppConfig.disableAds = !config.adsEnabled;
      expect(AppConfig.disableAds, isFalse);
    });

    test('All other flavors have ads enabled by default', () {
      final flavors = [
        AppFlavor.anime,
        AppFlavor.diamond,
        AppFlavor.stitch,
        AppFlavor.bead,
        AppFlavor.brick,
        AppFlavor.knit,
        AppFlavor.mosaic,
        AppFlavor.glow,
        AppFlavor.sticker,
        AppFlavor.quilt,
        AppFlavor.voxel,
      ];

      for (final flavor in flavors) {
        final config = FlavorConfig.of(flavor);
        expect(config.adsEnabled, isTrue, reason: '${flavor.name} must have adsEnabled: true');
      }
    });

    test('AppConfig.showAds defaults to true', () {
      expect(AppConfig.showAds, isTrue, reason: 'AppConfig.showAds must default to true to prevent race conditions on cold start');
    });

    test('RemoteConfig default show_ads for all requested flavors is true', () {
      final rc = RemoteConfigService();
      rc.attachStorage(storage);

      // Verify that all flavors default to show_ads: true
      for (final flavor in [AppFlavor.original, AppFlavor.devotional, AppFlavor.pixelcalm, AppFlavor.bible]) {
        setFlavorForTesting(flavor);
        expect(rc.showAds, isTrue, reason: '${flavor.name} showAds should be true by default');
      }
    });
  });
}

