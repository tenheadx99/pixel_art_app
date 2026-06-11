import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> incrementCompleted(String id) async {}
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

    test('completing a non-daily art does not affect the streak', () async {
      final provider = await providerWith({});
      final nonDaily = catalog.firstWhere(
        (a) => a.id != provider.dailyArt!.id,
      );
      provider.markCompleted(nonDaily.id);
      expect(provider.dailyStreak, 0);
    });

    test('a missed day breaks the streak on load', () async {
      final provider = await providerWith({
        'daily_streak': 7,
        'daily_last_date': '2020-01-01',
      });
      expect(provider.dailyStreak, 0);
    });
  });
}
