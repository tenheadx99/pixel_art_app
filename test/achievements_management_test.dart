import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/models/achievement_config.dart';
import 'package:pixel_art_app/data/services/achievement_service.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/sound_service.dart';
import 'package:pixel_art_app/l10n/app_localizations.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/ui/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late DatabaseService database;
  late AppSettingsProvider settings;
  late GalleryProvider gallery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pixelart_achievements': 'complete_first,fill_10',
    });
    storage = LocalStorageService();
    await storage.init();
    database = DatabaseService();
    settings = AppSettingsProvider(storage);
    gallery = GalleryProvider(storage, database);
    await AchievementService().initialize();
  });

  group('AchievementService & Dynamic Achievements Tests', () {
    test('Historical user progress is preserved (complete_first and fill_10 unlocked)', () {
      final service = AchievementService();
      expect(service.isUnlocked('complete_first'), isTrue);
      expect(service.isUnlocked('fill_10'), isTrue);
      expect(service.isUnlocked('daily_streak_7'), isFalse);
    });

    test('evaluateStats retroactively unlocks qualifying achievements without resetting progress', () async {
      final service = AchievementService();
      // User with 5 completed artworks and 7-day daily streak
      final newlyUnlocked = await service.evaluateStats(
        completedArts: 5,
        dailyStreak: 7,
        playerLevel: 5,
        bombsUsed: 10,
        wandsUsed: 10,
        customArtsCreated: 1,
      );

      final unlockedIds = newlyUnlocked.map((a) => a.id).toSet();
      expect(unlockedIds.contains('complete_5_arts'), isTrue);
      expect(unlockedIds.contains('daily_streak_3'), isTrue);
      expect(unlockedIds.contains('daily_streak_7'), isTrue);
      expect(unlockedIds.contains('use_bombs_10'), isTrue);
      expect(unlockedIds.contains('reach_level_5'), isTrue);
      expect(unlockedIds.contains('create_custom_art'), isTrue);

      // Verify that previously unlocked achievements remain unlocked
      expect(service.isUnlocked('complete_first'), isTrue);
      expect(service.isUnlocked('fill_10'), isTrue);
    });

    test('getProgressForItem calculates accurate fraction and clamped values', () {
      final service = AchievementService();
      const item = AchievementItem(
        id: 'complete_25_arts',
        title: 'Gallery Virtuoso',
        description: 'Finish 25 artworks',
        howToUnlock: 'Complete 25 artworks',
        metricType: 'completed_arts',
        targetValue: 25,
      );

      final p = service.getProgressForItem(
        item,
        completedArts: 10,
        dailyStreak: 3,
        playerLevel: 4,
        bombsUsed: 2,
        wandsUsed: 5,
        customArtsCreated: 0,
      );

      expect(p.current, 10);
      expect(p.target, 25);
      expect(p.progress, closeTo(0.4, 0.001));
    });
  });

  testWidgets('ProfileScreen renders Achievements and category filter chips', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalStorageService>.value(value: storage),
          ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GalleryProvider>.value(value: gallery),
          Provider<SoundService>.value(value: SoundService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Achievements Section Header exists
    expect(find.text('Achievements'), findsOneWidget);

    // Verify Category Filter Chips exist
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('Streaks & Daily'), findsOneWidget);

    // Verify default achievements render
    expect(find.text('First Masterpiece'), findsOneWidget);
    expect(find.text('Getting Started'), findsOneWidget);
  });
}
