import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/flavor.dart';
import '../models/pixel_art.dart';
import 'local_storage_service.dart';

/// Reads the admin-published catalog from Firestore and merges it with the
/// bundled assets. Paths and merge semantics mirror the admin panel's
/// `FirestorePaths`/`CatalogService` (pixel_art_admin repo) — the two must
/// stay in sync.
///
/// Layout under `pixel_art/{flavorId}`:
///  - root doc: `catalogVersion`, a monotonic int bumped on every mutation
///  - `artworks/{rmt_*}`: full PixelArt JSON + `visible` + `sortOrder`
///  - `overrides/{bundledArtId}`: sparse metadata overrides for bundled art
///    (`hidden`, `isPremium`, `category`, `sortOrder`)
///  - `stats/{artId}`: anonymous completion counters (written by the app)
///
/// The heavy collections are refetched from the server only when
/// `catalogVersion` differs from the last successfully fetched one; otherwise
/// they are served from Firestore's local persistence. An unchanged catalog
/// therefore costs one document read per launch, and offline launches fall
/// back to the persisted data automatically.
class RemoteCatalogService {
  final LocalStorageService _storage;

  RemoteCatalogService(this._storage);

  static const String _root = 'pixel_art';

  final String _flavorId = currentFlavor.name;

  String get _versionPrefKey => 'remote_catalog_version_$_flavorId';

  /// Fetches the remote catalog and returns it merged with [bundled], or null
  /// when nothing remote is reachable (no catalog published yet, offline with
  /// a cold cache, or Firebase failed to initialize) — callers then keep the
  /// bundled catalog as-is.
  Future<List<PixelArt>?> fetchCatalog(List<PixelArt> bundled) async {
    try {
      final db = FirebaseFirestore.instance;
      final rootSnap = await db.doc('$_root/$_flavorId').get();
      final version = (rootSnap.data()?['catalogVersion'] as num?)?.toInt();
      if (version == null) return null;

      final cachedVersion = _storage.getInt(_versionPrefKey, defaultValue: -1);
      var snaps = version == cachedVersion
          ? await _getCollections(db, Source.cache)
          : null;
      // Version changed since the last fetch (or the local cache was
      // evicted): go to the server.
      snaps ??= await _getCollections(db, Source.serverAndCache);
      if (snaps == null) return null;

      _storage.setInt(_versionPrefKey, version);
      return mergeCatalog(bundled, snaps.$1, snaps.$2);
    } catch (_) {
      return null;
    }
  }

  /// Anonymous per-art completion counter for the admin dashboard
  /// (`stats/{artId}.completions`). Fire-and-forget: the security rules only
  /// accept this exact shape, and failures are irrelevant to gameplay.
  void reportCompletion(String artId) {
    try {
      FirebaseFirestore.instance
          .doc('$_root/$_flavorId/stats/$artId')
          .set(
            {'completions': FieldValue.increment(1)},
            SetOptions(merge: true),
          )
          .catchError((_) {});
    } catch (_) {
      // Firebase unavailable — stats are best-effort.
    }
  }

  Future<
      (
        List<Map<String, dynamic>>,
        Map<String, Map<String, dynamic>>,
      )?> _getCollections(FirebaseFirestore db, Source source) async {
    try {
      final options = GetOptions(source: source);
      final snaps = await Future.wait([
        db.collection('$_root/$_flavorId/artworks').get(options),
        db.collection('$_root/$_flavorId/overrides').get(options),
      ]);
      // An empty cache result is indistinguishable from an evicted cache;
      // treat it as a miss so the caller refetches from the server (a real
      // fully-empty catalog just costs that one cheap re-query).
      if (source == Source.cache && snaps.every((s) => s.docs.isEmpty)) {
        return null;
      }
      return (
        [for (final d in snaps[0].docs) d.data()],
        {for (final d in snaps[1].docs) d.id: d.data()},
      );
    } on FirebaseException {
      if (source == Source.cache) return null;
      rethrow;
    }
  }

  /// Merge rule (mirrors the admin panel's `CatalogEntry`):
  ///  - bundled art: dropped when its override says `hidden`; `isPremium` and
  ///    `category` overridden when set; sortOrder = override or manifest index
  ///  - remote art: dropped when not `visible` or outside its availability
  ///    window; sortOrder from the doc (default 0)
  ///  - sorted by sortOrder, insertion order as the tiebreak
  static List<PixelArt> mergeCatalog(
    List<PixelArt> bundled,
    List<Map<String, dynamic>> artworkDocs,
    Map<String, Map<String, dynamic>> overrides,
  ) {
    final entries = <(PixelArt, int, int)>[];

    for (var i = 0; i < bundled.length; i++) {
      final art = bundled[i];
      final o = overrides[art.id];
      if (o?['hidden'] == true) continue;
      final premium = o?['isPremium'] as bool?;
      final rawCategory = o?['category'] as String?;
      final category =
          (rawCategory == null || rawCategory.isEmpty) ? null : rawCategory;
      entries.add((
        (premium == null && category == null)
            ? art
            : art.copyWith(isPremium: premium, category: category),
        (o?['sortOrder'] as num?)?.toInt() ?? i,
        entries.length,
      ));
    }

    final now = DateTime.now();
    for (final data in artworkDocs) {
      if (data['visible'] == false) continue;
      final PixelArt art;
      try {
        art = PixelArt.fromJson(data);
      } catch (_) {
        continue; // One malformed doc must not take down the whole catalog.
      }
      if (art.availableFrom != null && now.isBefore(art.availableFrom!)) {
        continue;
      }
      if (art.availableUntil != null && now.isAfter(art.availableUntil!)) {
        continue;
      }
      entries.add((
        art,
        (data['sortOrder'] as num?)?.toInt() ?? 0,
        entries.length,
      ));
    }

    entries.sort((a, b) {
      final bySort = a.$2.compareTo(b.$2);
      return bySort != 0 ? bySort : a.$3.compareTo(b.$3);
    });
    return [for (final e in entries) e.$1];
  }
}
