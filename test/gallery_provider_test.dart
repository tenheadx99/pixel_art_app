import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

class _FakeDatabaseService extends DatabaseService {
  final List<String> incremented = [];

  @override
  Future<void> incrementCompleted(String id) async {
    incremented.add(id);
  }
}

PixelArt _art(String id) => PixelArt(
  id: id,
  name: id,
  gridWidth: 2,
  gridHeight: 2,
  grid: const [
    [1, 1],
    [1, 1],
  ],
  colorMap: const {1: Color(0xFFFF0000)},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = List.generate(5, (i) => _art('art_$i'));

  group('dailyArtFor', () {
    test('is deterministic for a given date', () {
      final a = GalleryProvider.dailyArtFor(DateTime(2026, 6, 12), catalog);
      final b = GalleryProvider.dailyArtFor(DateTime(2026, 6, 12, 23), catalog);
      expect(a!.id, b!.id);
    });

    test('rotates day to day', () {
      final a = GalleryProvider.dailyArtFor(DateTime(2026, 6, 12), catalog);
      final b = GalleryProvider.dailyArtFor(DateTime(2026, 6, 13), catalog);
      expect(a!.id, isNot(b!.id));
    });

    test('returns null for an empty catalog', () {
      expect(GalleryProvider.dailyArtFor(DateTime(2026, 6, 12), []), isNull);
    });
  });

  group('daily streak', () {
    Future<GalleryProvider> providerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      final provider = GalleryProvider(storage, _FakeDatabaseService());
      await provider.loadCatalog(catalog);
      return provider;
    }

    test('completing the daily art starts a streak', () async {
      final provider = await providerWith({});
      provider.markCompleted(provider.dailyArt!.id);
      expect(provider.dailyStreak, 1);
      expect(provider.dailyCompletedToday, isTrue);
    });

    test('completing it twice the same day counts once', () async {
      final provider = await providerWith({});
      provider.markCompleted(provider.dailyArt!.id);
      provider.markCompleted(provider.dailyArt!.id);
      expect(provider.dailyStreak, 1);
    });

    test('completing a non-daily art keeps the streak, not the daily state',
        () async {
      final provider = await providerWith({});
      final nonDaily = catalog.firstWhere(
        (a) => a.id != provider.dailyArt!.id,
      );
      provider.markCompleted(nonDaily.id);
      expect(provider.dailyStreak, 1);
      expect(provider.dailyCompletedToday, isFalse);
    });

    test('a missed day breaks the streak on load', () async {
      final provider = await providerWith({
        'daily_streak': 7,
        'daily_last_date': '2020-01-01',
      });
      expect(provider.dailyStreak, 0);
    });
  });

  group('split artworks', () {
    // 4x4 parent split 2x2 (each part 2x2); the top-left tile is empty, the
    // top-right tile has 2 fillable cells, the bottom tiles 4 each.
    PixelArt splitParent() => PixelArt(
      id: 'rmt_split',
      name: 'Split',
      gridWidth: 4,
      gridHeight: 4,
      grid: const [
        [0, 0, 1, 0],
        [0, 0, 0, 1],
        [1, 1, 1, 1],
        [1, 1, 1, 1],
      ],
      colorMap: const {1: Color(0xFFFF0000)},
      partsX: 2,
      partsY: 2,
    );

    String pctKey(int part) => 'pixelart_progress_rmt_split_p${part}_pct';

    Future<(GalleryProvider, _FakeDatabaseService)> providerWith(
      Map<String, Object> prefs,
    ) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      final db = _FakeDatabaseService();
      final provider = GalleryProvider(storage, db);
      await provider.loadCatalog([splitParent(), ...catalog]);
      return (provider, db);
    }

    test('artProgressPercent weights parts by fillable cells', () async {
      final (provider, _) = await providerWith({
        pctKey(1): 100, // 2 fillable cells
        pctKey(2): 50, // 4 fillable cells
      });
      final parent = provider.catalog.first;
      // done = 2*100 + 4*50 = 400 of total 10 fillable => 40%.
      expect(provider.artProgressPercent(parent), 40);
      // Non-split art still reads its own pct key.
      expect(provider.artProgressPercent(catalog.first), 0);
    });

    test('untouched split art reports zero progress', () async {
      final (provider, _) = await providerWith({});
      expect(provider.artProgressPercent(provider.catalog.first), 0);
      expect(provider.inProgressArts, isEmpty);
    });

    test('a started split parent appears in the continue row', () async {
      final (provider, _) = await providerWith({pctKey(2): 50});
      expect(
        provider.inProgressArts.map((a) => a.id),
        contains('rmt_split'),
      );
    });

    test('empty parts count as complete', () async {
      final (provider, _) = await providerWith({
        pctKey(1): 100,
        pctKey(2): 100,
        pctKey(3): 100,
        // part 0 has no fillable cells and no save at all.
      });
      expect(provider.partsAllComplete(provider.catalog.first), isTrue);
      expect(provider.partProgressPercent(provider.catalog.first, 0), 100);
    });

    test('finishing the last part cascades completion to the parent', () async {
      final (provider, db) = await providerWith({
        pctKey(1): 100,
        pctKey(2): 100,
        pctKey(3): 100,
      });
      provider.markCompleted('rmt_split_p3');
      expect(provider.isCompleted('rmt_split'), isTrue);
      // Stats are reported once for the parent, never for part ids.
      expect(db.incremented, ['rmt_split']);
    });

    test('an unfinished sibling blocks the parent cascade', () async {
      final (provider, db) = await providerWith({
        pctKey(1): 100,
        pctKey(2): 60,
        pctKey(3): 100,
      });
      provider.markCompleted('rmt_split_p3');
      expect(provider.isCompleted('rmt_split_p3'), isTrue);
      expect(provider.isCompleted('rmt_split'), isFalse);
      expect(db.incremented, isEmpty);
    });

    test('parent completion is not reported twice', () async {
      final (provider, db) = await providerWith({
        pctKey(1): 100,
        pctKey(2): 100,
        pctKey(3): 100,
      });
      provider.markCompleted('rmt_split_p3');
      provider.markCompleted('rmt_split_p1');
      expect(db.incremented, ['rmt_split']);
    });
  });

  group('streak insurance', () {
    Future<GalleryProvider> providerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      final provider = GalleryProvider(storage, _FakeDatabaseService());
      await provider.loadCatalog(catalog);
      return provider;
    }

    test('auto-consumes streak freeze on a missed day', () async {
      final provider = await providerWith({
        'daily_streak': 12,
        'daily_last_date': '2020-01-01',
        'streak_freezes': 1,
      });
      expect(provider.dailyStreak, 12);
      expect(provider.streakFreezes, 0);
    });

    test('records broken streak when freezes is zero', () async {
      final provider = await providerWith({
        'daily_streak': 15,
        'daily_last_date': '2020-01-01',
        'streak_freezes': 0,
      });
      expect(provider.dailyStreak, 0);
      expect(provider.canRepairStreak, isTrue);
      expect(provider.streakBrokenValue, 15);
    });

    test('repairs streak with diamonds', () async {
      final provider = await providerWith({
        'daily_streak': 0,
        'streak_broken_at_ms': DateTime.now().millisecondsSinceEpoch,
        'streak_broken_value': 25,
        'diamonds_available': 500,
      });
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      await settings.loadSettings();

      expect(provider.canRepairStreak, isTrue);
      final success = provider.repairStreakWithDiamonds(settings);
      expect(success, isTrue);
      expect(provider.dailyStreak, 25);
      expect(provider.canRepairStreak, isFalse);
      expect(settings.diamondsAvailable, 200);
    });

    test('grants 1 monthly streak freeze for Plus subscribers', () async {
      final provider = await providerWith({'streak_freezes': 0});
      provider.checkAndGrantPlusMonthlyFreeze(true);
      expect(provider.streakFreezes, 1);
      // Second call in same month does not duplicate
      provider.checkAndGrantPlusMonthlyFreeze(true);
      expect(provider.streakFreezes, 1);
    });
  });

  group('recency ordering', () {
    test('inProgressArts orders by progress timestamp descending and caps at 10', () async {
      final manyCatalog = List.generate(15, (i) => _art('art_$i'));
      final prefs = <String, Object>{};
      for (int i = 0; i < 15; i++) {
        prefs['pixelart_progress_art_${i}_pct'] = 50;
        prefs['pixelart_progress_art_${i}_ts'] = 1000 + i;
      }
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      final provider = GalleryProvider(storage, _FakeDatabaseService());
      await provider.loadCatalog(manyCatalog);

      final inProgress = provider.inProgressArts;
      expect(inProgress.length, 10);
      expect(inProgress.first.id, 'art_14');
      expect(inProgress.last.id, 'art_5');
    });
  });
}
