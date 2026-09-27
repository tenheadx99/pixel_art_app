import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService Unit Tests', () {
    final analytics = AnalyticsService();

    test('initializes and handles absent Firebase safely without throwing', () async {
      await expectLater(analytics.init(flavorName: 'original'), completes);
    });

    test('artwork lifecycle methods complete without throwing when offline', () async {
      await expectLater(
        analytics.logArtworkSelected(artId: 'test_art', category: 'animals', title: 'Puppy'),
        completes,
      );
      await expectLater(
        analytics.logArtworkCleared(artId: 'test_art', progressPct: 40),
        completes,
      );
      await expectLater(
        analytics.logUndoUsed(artId: 'test_art'),
        completes,
      );
    });

    test('virtual currency methods complete without throwing', () async {
      await expectLater(
        analytics.logSpendVirtualCurrency(itemName: 'artwork_unlock', value: 100, artId: 'test_art'),
        completes,
      );
      await expectLater(
        analytics.logEarnVirtualCurrency(source: 'level_up', value: 25),
        completes,
      );
      await expectLater(
        analytics.logArtworkUnlocked(artId: 'test_art', unlockType: 'diamond', diamondCost: 100),
        completes,
      );
    });

    test('auth and cloud sync methods complete without throwing', () async {
      await expectLater(analytics.logLogin(method: 'google'), completes);
      await expectLater(analytics.logSignUp(method: 'email'), completes);
      await expectLater(analytics.logAccountLinked(provider: 'google'), completes);
      await expectLater(
        analytics.logCloudSync(success: true, artworksCount: 5),
        completes,
      );
    });

    test('progression and engagement methods complete without throwing', () async {
      await expectLater(analytics.logLevelUp(level: 5, totalXp: 1200), completes);
      await expectLater(
        analytics.logFavoriteToggled(artId: 'test_art', isFavorite: true),
        completes,
      );
      await expectLater(analytics.logSearch(query: 'dragon'), completes);
      await expectLater(
        analytics.logSettingChanged(settingName: 'dark_mode', value: true),
        completes,
      );
      await expectLater(
        analytics.logStreakBroken(brokenStreakValue: 7),
        completes,
      );
      await expectLater(
        analytics.logStreakRepaired(repairedValue: 7),
        completes,
      );
    });

    test('navigation and IAP recovery methods complete without throwing', () async {
      await expectLater(
        analytics.logDailyPixelTapped(artId: 'test_daily', completedToday: false),
        completes,
      );
      await expectLater(
        analytics.logContinueRowTapped(artId: 'test_art', progressPct: 60),
        completes,
      );
      await expectLater(
        analytics.logGalleryFilterApplied(filterType: 'category', value: 'anime'),
        completes,
      );
      await expectLater(
        analytics.logPurchaseFailed(productId: 'diamond_pack_100', reason: 'cancelled'),
        completes,
      );
      await expectLater(
        analytics.logRestoreSuccess(productsRestored: 1),
        completes,
      );
      await expectLater(
        analytics.logRestoreFailed(errorCode: 'store_unavailable'),
        completes,
      );
    });
  });
}
