import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/daily_pixel_service.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> incrementCompleted(String id) async {}
}

/// Firestore-free schedule stub: returns [scheduledId], or throws when
/// [unreachable] (the real service throws when offline with a cold cache).
class _FakeDailyPixelService extends DailyPixelService {
  String? scheduledId;
  bool unreachable = false;

  _FakeDailyPixelService(super.storage);

  @override
  Future<String?> scheduledArtId(String dateKey) async {
    if (unreachable) throw Exception('offline');
    return scheduledId;
  }
}

PixelArt _art(
  String id, {
  bool premium = false,
  int partsX = 1,
  int partsY = 1,
}) => PixelArt(
  id: id,
  name: id,
  gridWidth: 2,
  gridHeight: 2,
  grid: const [
    [1, 1],
    [1, 1],
  ],
  colorMap: const {1: Color(0xFFFF0000)},
  isPremium: premium,
  partsX: partsX,
  partsY: partsY,
);

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = List.generate(5, (i) => _art('art_$i'));

  group('DailyPixelService.fallbackDailyFor', () {
    test('is deterministic within a day and rotates day to day', () {
      final a = DailyPixelService.fallbackDailyFor(
        DateTime(2026, 6, 12),
        catalog,
      );
      final b = DailyPixelService.fallbackDailyFor(
        DateTime(2026, 6, 12, 23),
        catalog,
      );
      final c = DailyPixelService.fallbackDailyFor(
        DateTime(2026, 6, 13),
        catalog,
      );
      expect(a!.id, b!.id);
      expect(a.id, isNot(c!.id));
    });

    test('never lands on a premium or split artwork', () {
      final mixed = [
        _art('a_premium', premium: true),
        _art('b_split', partsX: 2, partsY: 2),
        _art('c_free'),
      ];
      for (var day = 0; day < 10; day++) {
        final pick = DailyPixelService.fallbackDailyFor(
          DateTime(2026, 6, 1 + day),
          mixed,
        );
        expect(pick!.id, 'c_free');
      }
    });

    test('is stable when a publish adds premium art or reorders', () {
      final date = DateTime(2026, 6, 12);
      final before = DailyPixelService.fallbackDailyFor(date, catalog);
      final after = DailyPixelService.fallbackDailyFor(date, [
        _art('zzz_new', premium: true),
        ...catalog.reversed,
      ]);
      expect(after!.id, before!.id);
    });

    test('an all-premium catalog still yields a daily', () {
      final premiumOnly = [_art('p1', premium: true), _art('p2', premium: true)];
      expect(
        DailyPixelService.fallbackDailyFor(DateTime(2026, 6, 12), premiumOnly),
        isNotNull,
      );
    });

    test('returns null only for an empty catalog', () {
      expect(
        DailyPixelService.fallbackDailyFor(DateTime(2026, 6, 12), []),
        isNull,
      );
    });
  });

  group('DailyPixelService.scheduledArtId', () {
    final today = _dateKey(DateTime.now());

    Future<DailyPixelService> serviceWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      return DailyPixelService(storage);
    }

    test('serves a cached schedule entry without touching Firestore', () async {
      final service = await serviceWith({
        'daily_schedule_cache_original': '$today|rmt_x',
      });
      expect(await service.scheduledArtId(today), 'rmt_x');
    });

    test('a cached "unscheduled" answer resolves to null', () async {
      final service = await serviceWith({
        'daily_schedule_cache_original': '$today|__unscheduled__',
      });
      expect(await service.scheduledArtId(today), isNull);
    });

    test('throws (rather than "unscheduled") when the backend is unreachable',
        () async {
      // No Firebase in unit tests: a cache miss must surface as an error the
      // caller retries later, never as a definitive "no schedule".
      final service = await serviceWith({
        'daily_schedule_cache_original': '2020-01-01|stale',
      });
      expect(() => service.scheduledArtId(today), throwsA(anything));
    });
  });

  group('GalleryProvider.resolveDailyArt', () {
    late _FakeDailyPixelService schedule;

    Future<GalleryProvider> providerWith(
      Map<String, Object> prefs, {
      List<PixelArt>? arts,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      schedule = _FakeDailyPixelService(storage);
      final provider = GalleryProvider(
        storage,
        _FakeDatabaseService(),
        null,
        schedule,
      );
      await provider.loadCatalog(arts ?? catalog);
      return provider;
    }

    test('pins the admin-scheduled artwork', () async {
      final provider = await providerWith({});
      schedule.scheduledId = 'art_3';
      await provider.resolveDailyArt();
      expect(provider.dailyArt!.id, 'art_3');
    });

    test('pins the fallback when the day is unscheduled', () async {
      final provider = await providerWith({});
      await provider.resolveDailyArt();
      final expected = DailyPixelService.fallbackDailyFor(
        DateTime.now(),
        catalog,
      );
      expect(provider.dailyArt!.id, expected!.id);
      // The pick is now pinned in prefs for the day.
      final pinned = provider.dailyArt!.id;
      provider.updateCatalog([_art('aaa_new'), ...catalog]);
      expect(provider.dailyArt!.id, pinned);
    });

    test('pins the fallback when the scheduled id is not in the catalog',
        () async {
      final provider = await providerWith({});
      schedule.scheduledId = 'rmt_missing';
      await provider.resolveDailyArt();
      expect(provider.dailyArt, isNotNull);
      expect(provider.dailyArt!.id, isNot('rmt_missing'));
    });

    test('a mid-day catalog publish cannot swap a pinned daily', () async {
      final provider = await providerWith({});
      schedule.scheduledId = 'art_2';
      await provider.resolveDailyArt();
      // Publish reshuffles the catalog: new art sorts first, order reversed.
      provider.updateCatalog([_art('aaa_new'), ...catalog.reversed]);
      expect(provider.dailyArt!.id, 'art_2');
    });

    test('resolution is once per day: a later schedule change is ignored',
        () async {
      final provider = await providerWith({});
      schedule.scheduledId = 'art_1';
      await provider.resolveDailyArt();
      schedule.scheduledId = 'art_4';
      await provider.resolveDailyArt();
      expect(provider.dailyArt!.id, 'art_1');
    });

    test('an unreachable schedule leaves today unpinned but daily served',
        () async {
      final provider = await providerWith({});
      schedule.unreachable = true;
      await provider.resolveDailyArt();
      // No pin written: the next resolve may still adopt the schedule.
      final pinKey = 'daily_art_id_${_dateKey(DateTime.now())}';
      expect(
        (await SharedPreferences.getInstance()).getString(pinKey),
        isNull,
      );
      // The banner still has a (fallback) daily meanwhile.
      expect(provider.dailyArt, isNotNull);
      schedule.unreachable = false;
      schedule.scheduledId = 'art_3';
      await provider.resolveDailyArt();
      expect(provider.dailyArt!.id, 'art_3');
    });

    test('an existing pin short-circuits without a schedule read', () async {
      final pinKey = 'daily_art_id_${_dateKey(DateTime.now())}';
      final provider = await providerWith({pinKey: 'art_4'});
      schedule.unreachable = true; // would throw if consulted
      await provider.resolveDailyArt();
      expect(provider.dailyArt!.id, 'art_4');
    });
  });

  group('widened streak credit', () {
    Future<GalleryProvider> providerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = LocalStorageService();
      await storage.init();
      final provider = GalleryProvider(storage, _FakeDatabaseService());
      await provider.loadCatalog(catalog);
      return provider;
    }

    test('a non-daily completion keeps the streak alive', () async {
      final provider = await providerWith({});
      final nonDaily = catalog.firstWhere(
        (a) => a.id != provider.dailyArt!.id,
      );
      provider.markCompleted(nonDaily.id);
      expect(provider.dailyStreak, 1);
      // ...but only the daily itself flips the banner/bonus state.
      expect(provider.dailyCompletedToday, isFalse);
    });

    test('the streak advances at most once per day', () async {
      final provider = await providerWith({});
      provider.markCompleted('art_0');
      provider.markCompleted('art_1');
      expect(provider.dailyStreak, 1);
    });

    test('completing the daily still marks the banner done', () async {
      final provider = await providerWith({});
      provider.markCompleted(provider.dailyArt!.id);
      expect(provider.dailyStreak, 1);
      expect(provider.dailyCompletedToday, isTrue);
    });

    test('pre-upgrade "daily done" state migrates to the new done-date',
        () async {
      final today = _dateKey(DateTime.now());
      final provider = await providerWith({
        'daily_streak': 3,
        'daily_last_date': today,
      });
      expect(provider.dailyStreak, 3);
      expect(provider.dailyCompletedToday, isTrue);
    });
  });
}
