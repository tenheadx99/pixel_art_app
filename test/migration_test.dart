import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/coloring_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/config/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Migration from Old Version to New Dynamic Version', () {
    test('loads saved progress created in older app version', () async {
      // 1. Mock legacy SharedPreferences state (as saved by older version)
      final legacyPrefs = <String, Object>{
        'magic_wands_count': 3,
        'bombs_count': 4,
        'brushes_count': 2,
        'completed_ids': ['old_art_1'],
        'favorite_ids': ['dynamic_art_2'],
        // Old save progress for artwork 'dynamic_art_2' (2x2 grid)
        'pixelart_progress_dynamic_art_2': '1,0;0,2',
        'pixelart_progress_dynamic_art_2_pct': 50,
        'pixelart_progress_dynamic_art_2_fills': 2,
        'pixelart_progress_dynamic_art_2_timelapse': '0,0;1,1',
      };

      SharedPreferences.setMockInitialValues(legacyPrefs);

      final storage = LocalStorageService();
      await storage.init();
      final db = DatabaseService();

      // 2. Load GalleryProvider with new dynamic artwork catalog
      final galleryProvider = GalleryProvider(storage, db);
      
      final dynamicArt = PixelArt(
        id: 'dynamic_art_2',
        name: 'Migrated Dynamic Artwork',
        gridWidth: 2,
        gridHeight: 2,
        grid: [
          [1, 1],
          [2, 2],
        ],
        colorMap: {
          1: const Color(0xFFFFFF00),
          2: const Color(0xFF0000FF),
        },
      );

      await galleryProvider.loadCatalog([dynamicArt]);

      // Verify gallery recognizes legacy in-progress artwork
      expect(galleryProvider.progressPercent('dynamic_art_2'), 50);
      expect(galleryProvider.inProgressArts.length, 1);
      expect(galleryProvider.isCompleted('old_art_1'), isTrue);

      // 3. Load ColoringProvider with the migrated artwork
      final coloringProvider = ColoringProvider(storage);
      coloringProvider.loadArt(dynamicArt);

      // Assert that old grid progress and booster counts are intact
      expect(coloringProvider.filledGrid[0][0], 1);
      expect(coloringProvider.filledGrid[1][1], 2);
      expect(coloringProvider.filledGrid[0][1], 0); // Unfilled
      expect(coloringProvider.magicWandsCount, 3);
      expect(coloringProvider.bombsCount, 4);
      expect(coloringProvider.totalFillCount, 2);
      expect(coloringProvider.timeLapse.length, 2);
    });

    test('gracefully handles grid dimension mismatch if dynamic art resized', () async {
      // If dynamic artwork dimension changed (e.g. from 2x2 to 3x3 in the new version)
      final legacyPrefs = <String, Object>{
        'pixelart_progress_dynamic_art_resized': '1,0;0,2', // 2x2 saved grid
      };

      SharedPreferences.setMockInitialValues(legacyPrefs);
      final storage = LocalStorageService();
      await storage.init();

      final coloringProvider = ColoringProvider(storage);
      final resizedArt = PixelArt(
        id: 'dynamic_art_resized',
        name: 'Resized Art',
        gridWidth: 3,
        gridHeight: 3,
        grid: [
          [1, 1, 1],
          [2, 2, 2],
          [1, 2, 1],
        ],
        colorMap: {1: const Color(0xFF000000)},
      );

      // Should safely reset to fresh grid instead of crashing on dimension mismatch
      coloringProvider.loadArt(resizedArt);
      expect(coloringProvider.filledGrid.length, 3);
      expect(coloringProvider.progress, 0.0);
    });

    test('retains diamond balance, boosters, and purchases across app update', () async {
      final preUpdatePrefs = <String, Object>{
        'diamonds_available': 350,
        'welcome_bonus_claimed': true,
        'total_xp': 420,
        'magic_wands_count': 7,
        'bombs_count': 12,
        'brushes_count': 6,
        'daily_streak': 14,
        'daily_last_date': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
        'streak_freezes': 2,
        AppConstants.proPrefKey: true,
        AppConstants.removeAdsPrefKey: true,
        'diamond_unlocked_ids': ['art_unlocked_1', 'art_unlocked_2'],
        'completed_ids': ['art_completed_1', 'art_completed_2'],
        'favorite_ids': ['art_fav_1'],
      };

      SharedPreferences.setMockInitialValues(preUpdatePrefs);
      final storage = LocalStorageService();
      await storage.init();
      final db = DatabaseService();

      final settings = AppSettingsProvider(storage);
      final gallery = GalleryProvider(storage, db);

      final unlockedArt = PixelArt(
        id: 'art_unlocked_1',
        name: 'Unlocked Art',
        gridWidth: 2,
        gridHeight: 2,
        grid: [[1, 1], [1, 1]],
        colorMap: {1: const Color(0xFF000000)},
        isPremium: true,
      );
      await gallery.loadCatalog([unlockedArt]);

      // Welcome bonus check on new app version boot should NOT reset or overwrite diamonds
      final welcomeAward = settings.checkAndClaimWelcomeBonus();
      expect(welcomeAward, 0); // Already claimed in previous version

      // Verify all economy and progress metrics survived the app upgrade
      expect(settings.diamondsAvailable, 350);
      expect(settings.isProUser, isTrue);
      expect(settings.totalXp, 420);
      expect(gallery.streakFreezes, 2);
      expect(gallery.isUnlocked(unlockedArt, false), isTrue);
      expect(gallery.isCompleted('art_completed_1'), isTrue);
      expect(gallery.isFavorite('art_fav_1'), isTrue);
      expect(gallery.dailyStreak, 14);

      // ColoringProvider should load pre-update booster counts
      final coloring = ColoringProvider(storage);
      coloring.loadArt(unlockedArt);
      expect(coloring.magicWandsCount, 7);
      expect(coloring.bombsCount, 12);
    });

    test('preserves low diamond balance without wipe if user spent diamonds before updating', () async {
      final preUpdatePrefs = <String, Object>{
        'diamonds_available': 15, // User spent diamonds on boosters
        'welcome_bonus_claimed': true,
      };

      SharedPreferences.setMockInitialValues(preUpdatePrefs);
      final storage = LocalStorageService();
      await storage.init();

      final settings = AppSettingsProvider(storage);
      final welcomeAward = settings.checkAndClaimWelcomeBonus();
      expect(welcomeAward, 0);
      expect(settings.diamondsAvailable, 15);
    });
  });
}
