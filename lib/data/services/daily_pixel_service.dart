import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/flavor.dart';
import '../models/pixel_art.dart';
import 'local_storage_service.dart';

/// Resolves which artwork is the Daily Pixel for a given day.
///
/// Resolution order (driven by `GalleryProvider.resolveDailyArt`):
///  1. Admin schedule: `pixel_art/{flavorId}/daily_schedule/{yyyy-MM-dd}` ->
///     `{artId}`, written by the admin panel's Daily Schedule screen. Read at
///     most once per day; the answer (including "unscheduled") is cached in
///     prefs, so this costs one document read per day.
///  2. Deterministic fallback over the catalog ([fallbackDailyFor]).
///
/// The resolved id is then pinned for the day by the provider, so an admin
/// publish that reshuffles the catalog mid-day can no longer swap the daily
/// out from under users and break their streaks.
class DailyPixelService {
  final LocalStorageService _storage;

  DailyPixelService(this._storage);

  static const String _root = 'pixel_art';

  final String _flavorId = currentFlavor.name;

  /// Single self-cleaning cache slot, `<yyyy-MM-dd>|<artId or marker>`.
  String get _cachePrefKey => 'daily_schedule_cache_$_flavorId';

  /// Cached when the schedule definitively has no entry for the day —
  /// distinguishes "checked, unscheduled" from "never checked".
  static const String _unscheduled = '__unscheduled__';

  /// The admin-scheduled art id for [dateKey] (`yyyy-MM-dd`), or null when
  /// the day has no schedule entry. Throws when the schedule is unreachable
  /// (offline with a cold cache) — callers must retry later rather than
  /// treat that as "unscheduled".
  Future<String?> scheduledArtId(String dateKey) async {
    final cached = _storage.getString(_cachePrefKey);
    final sep = cached.indexOf('|');
    if (sep > 0 && cached.substring(0, sep) == dateKey) {
      final id = cached.substring(sep + 1);
      return id == _unscheduled ? null : id;
    }
    final snap = await FirebaseFirestore.instance
        .doc('$_root/$_flavorId/daily_schedule/$dateKey')
        .get();
    final artId = (snap.data()?['artId'] as String?) ?? '';
    _storage.setString(
      _cachePrefKey,
      '$dateKey|${artId.isEmpty ? _unscheduled : artId}',
    );
    return artId.isEmpty ? null : artId;
  }

  /// Deterministic schedule-less daily for [date]: free, non-split artworks
  /// sorted by id (stable across publishes, unlike sortOrder), indexed by day
  /// number. A premium daily would dead-end free users at the locked dialog,
  /// and a split daily would demand every tile for one streak day. Falls back
  /// to the whole catalog if nothing qualifies, and to null only when
  /// [catalog] itself is empty.
  static PixelArt? fallbackDailyFor(DateTime date, List<PixelArt> catalog) {
    if (catalog.isEmpty) return null;
    var pool = [
      for (final a in catalog)
        if (!a.isPremium && !a.isSplit) a,
    ];
    if (pool.isEmpty) pool = List.of(catalog);
    pool.sort((a, b) => a.id.compareTo(b.id));
    final dayNumber = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(2026)).inDays;
    return pool[dayNumber.abs() % pool.length];
  }
}
