import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_constants.dart';
import '../../config/flavor.dart';
import '../../config/version_utils.dart';
import '../models/pixel_art.dart';
import '../models/split_art.dart';
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

  bool _premiumArtworksEnabled = true;
  bool get premiumArtworksEnabled => _premiumArtworksEnabled;

  /// Artworks kept in the catalog only because this user has local state on
  /// them (progress/completed/favorite/diamond-unlocked): hidden bundled art
  /// and cache-restored remote art. They stay colorable but are excluded from
  /// promotion surfaces (daily fallback). Populated by [fetchCatalog] and
  /// [withRestoredCachedArts].
  Set<String> get retiredIds => _retiredIds;
  Set<String> _retiredIds = {};

  /// Fetches the remote catalog and returns it merged with [bundled], or null
  /// when nothing remote is reachable (no catalog published yet, offline with
  /// a cold cache, or Firebase failed to initialize) — callers then keep the
  /// bundled catalog as-is.
  Future<List<PixelArt>?> fetchCatalog(List<PixelArt> bundled) async {
    _retiredIds = {};
    try {
      final db = FirebaseFirestore.instance;
      final rootSnap = await db.doc('$_root/$_flavorId').get();
      final rootData = rootSnap.data();
      if (rootData != null && rootData.containsKey('premiumArtworksEnabled')) {
        _premiumArtworksEnabled = rootData['premiumArtworksEnabled'] == true;
      }
      final version = (rootData?['catalogVersion'] as num?)?.toInt();
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
      String? appVersion;
      try {
        appVersion = (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        // Best-effort: without a version, gated docs are simply kept — any
        // build new enough to contain this code can render them. Failing the
        // whole fetch here would silently drop the entire remote catalog.
      }
      final artworkDocs = snaps.$1;
      final overrides = snaps.$2;
      // Progress hand-off must run before computing the retained set: a
      // successfully handed-off original needs no retention (its progress now
      // lives on the replacement, which is in the catalog).
      final handedOff = applyReplacementHandOffs(
        bundled,
        artworkDocs,
        overrides,
        currentAppVersion: appVersion,
      );
      final keepHiddenIds = <String>{
        for (final art in bundled)
          if (overrides[art.id]?['hidden'] == true &&
              !handedOff.contains(art.id) &&
              _hasLocalState(art))
            art.id,
      };
      _retiredIds = keepHiddenIds;
      return mergeCatalog(
        bundled,
        artworkDocs,
        overrides,
        currentAppVersion: appVersion,
        keepHiddenIds: keepHiddenIds,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether this user has any persisted state on [art] (or, for split art,
  /// any of its parts): saved progress, completion, favorite, or a diamond
  /// unlock. Drives retention of artworks that would otherwise be dropped.
  bool _hasLocalState(PixelArt art) {
    if (_idHasLocalState(art.id)) return true;
    if (art.isSplit && SplitArt.validSplit(art)) {
      for (int i = 0; i < art.partCount; i++) {
        if (_idHasLocalState(SplitArt.partId(art.id, i))) return true;
      }
    }
    return false;
  }

  bool _idHasLocalState(String id) =>
      _storage.getInt('pixelart_progress_${id}_pct') > 0 ||
      _storage.getString('pixelart_progress_$id').isNotEmpty ||
      _storage.getStringSet(AppConstants.completedIdsPrefKey).contains(id) ||
      _storage.getStringSet('favorite_ids').contains(id) ||
      _storage.getStringSet('diamond_unlocked_ids').contains(id);

  /// [_hasLocalState] for a cached artwork we haven't parsed yet: probe the
  /// possible split-part ids by pattern instead of the real part count (split
  /// parents carry progress only on their part keys, never the base id).
  bool _cachedIdHasState(String id) {
    if (_idHasLocalState(id)) return true;
    for (int i = 0; i < SplitArt.maxParts; i++) {
      if (_idHasLocalState(SplitArt.partId(id, i))) return true;
    }
    return false;
  }

  static final RegExp _replacementIdPattern = RegExp(r'^rmt_(.+)_\d+$');

  /// The bundled artwork [doc] replaces, or null. An explicit `replaces` field
  /// wins; older docs fall back to the admin id convention
  /// `rmt_<oldBundledId>_<millis>` (greedy group + anchored trailing digits,
  /// so underscored slugs like `bird_01` parse correctly). Either way the
  /// result must be an actual bundled id.
  static String? replacementTargetId(
    Map<String, dynamic> doc,
    Set<String> bundledIds,
  ) {
    final explicit = doc['replaces'];
    if (explicit is String && bundledIds.contains(explicit)) return explicit;
    final id = doc['id'];
    if (id is! String) return null;
    final oldId = _replacementIdPattern.firstMatch(id)?.group(1);
    return (oldId != null && bundledIds.contains(oldId)) ? oldId : null;
  }

  /// Whether a remote doc will actually be visible to this build after
  /// [mergeCatalog]'s gates, judged from scalar fields only (no grid parse).
  /// Mirrors the `visible` / `minAppVersion` / availability-window drops in
  /// [mergeCatalog] — keep the two in sync. A replacement that fails these
  /// gates must NOT count as handed off, or the hidden original would be
  /// dropped while its replacement is absent too and the artwork (plus the
  /// user's progress) would vanish from the catalog.
  static bool _docPassesGates(
    Map<String, dynamic> data,
    String? currentAppVersion,
  ) {
    if (data['visible'] == false) return false;
    final minVersion = data['minAppVersion'] as String?;
    if (minVersion != null &&
        currentAppVersion != null &&
        isVersionOlder(currentAppVersion, minVersion)) {
      return false;
    }
    final now = DateTime.now();
    final from = DateTime.tryParse(data['availableFrom'] as String? ?? '');
    if (from != null && now.isBefore(from)) return false;
    final until = DateTime.tryParse(data['availableUntil'] as String? ?? '');
    if (until != null && now.isAfter(until)) return false;
    return true;
  }

  /// Copies user progress from bundled artworks onto their admin-published
  /// replacements (`rmt_<oldId>_<millis>` + `hidden` on the original), once
  /// per replacement. Returns the bundled ids that were handed off. Called by
  /// [fetchCatalog]; visible so tests can drive it without Firestore.
  @visibleForTesting
  Set<String> applyReplacementHandOffs(
    List<PixelArt> bundled,
    List<Map<String, dynamic>> artworkDocs,
    Map<String, Map<String, dynamic>> overrides, {
    String? currentAppVersion,
  }) {
    final bundledById = {for (final a in bundled) a.id: a};
    final bundledIds = bundledById.keys.toSet();
    final handedOff = <String>{};
    for (final doc in artworkDocs) {
      final oldId = replacementTargetId(doc, bundledIds);
      if (oldId == null) continue;
      // The admin replace flow always hides the original; requiring that here
      // kills slug-collision false positives from the id-parsing fallback.
      if (overrides[oldId]?['hidden'] != true) continue;
      if (!_docPassesGates(doc, currentAppVersion)) continue;
      // Once the copy is done, skip the (expensive) full-grid parse below on
      // every subsequent launch — the marker alone decides.
      if (doc['id'] is String &&
          _storage.getBool('progress_handoff_done_${doc['id']}')) {
        handedOff.add(oldId);
        continue;
      }
      final old = bundledById[oldId]!;
      final PixelArt neu;
      try {
        neu = PixelArt.fromJson(doc);
      } catch (_) {
        continue;
      }
      if (neu.gridWidth != old.gridWidth ||
          neu.gridHeight != old.gridHeight ||
          neu.partsX != old.partsX ||
          neu.partsY != old.partsY) {
        // Layout changed: the save can't be transplanted. Deliberate fallback,
        // not an error — retention keeps the original playable and the
        // replacement simply appears as a fresh artwork.
        continue;
      }
      _handOffProgress(old, neu);
      handedOff.add(oldId);
    }
    return handedOff;
  }

  void _handOffProgress(PixelArt old, PixelArt neu) {
    final doneKey = 'progress_handoff_done_${neu.id}';
    if (_storage.getBool(doneKey)) return;

    final idPairs = <(String, String)>[(old.id, neu.id)];
    if (old.isSplit && SplitArt.validSplit(old)) {
      for (int i = 0; i < old.partCount; i++) {
        idPairs.add((SplitArt.partId(old.id, i), SplitArt.partId(neu.id, i)));
      }
    }
    for (final (oldId, newId) in idPairs) {
      _copyProgressFamily(oldId, newId);
      for (final setKey in const [
        AppConstants.completedIdsPrefKey,
        'favorite_ids',
        'diamond_unlocked_ids',
      ]) {
        // Copy, never move: the old entries keep the bundled art fully
        // functional when the app is offline and the merge never runs. The
        // profile "done" count including both copies is an accepted cosmetic.
        if (_storage.getStringSet(setKey).contains(oldId)) {
          _storage.addToStringSet(setKey, newId);
        }
      }
      // Without this, completing the replacement would pay the completion
      // diamonds a second time.
      if (_storage.getBool('${AppConstants.diamondsAwardedPrefix}$oldId')) {
        _storage.setBool('${AppConstants.diamondsAwardedPrefix}$newId', true);
      }
    }
    _storage.setBool(doneKey, true);
  }

  void _copyProgressFamily(String oldId, String newId) {
    final oldKey = 'pixelart_progress_$oldId';
    final newKey = 'pixelart_progress_$newId';
    // Nothing to copy (common for untouched split parts): skip the 7 writes —
    // each one is a platform-channel message plus a prefs commit, and a split
    // parent hands off up to 26 key families in one launch.
    if (_storage.getString(oldKey).isEmpty &&
        _storage.getInt('${oldKey}_pct') == 0) {
      return;
    }
    // No-clobber: the user may already have started the replacement (e.g. on
    // a build that predates the hand-off).
    if (_storage.getString(newKey).isNotEmpty ||
        _storage.getInt('${newKey}_pct') > 0) {
      return;
    }
    _storage.setString(newKey, _storage.getString(oldKey));
    _storage.setInt('${newKey}_pct', _storage.getInt('${oldKey}_pct'));
    _storage.setInt('${newKey}_ts', _storage.getInt('${oldKey}_ts'));
    _storage.setInt('${newKey}_fills', _storage.getInt('${oldKey}_fills'));
    _storage.setInt('${newKey}_erases', _storage.getInt('${oldKey}_erases'));
    _storage.setString(
      '${newKey}_timelapse',
      _storage.getString('${oldKey}_timelapse'),
    );
    _storage.setString(
      '${newKey}_milestones',
      _storage.getString('${oldKey}_milestones'),
    );
  }

  String get _cacheIndexKey => 'cached_remote_art_ids_$_flavorId';

  /// Persists a remote artwork's JSON locally so it stays playable if its
  /// Firestore doc later vanishes (deleted, expired, hidden). Called when the
  /// user opens the artwork; overwriting on every open keeps the copy fresh
  /// after admin edits. Split parts are never cached — the parent doc is
  /// authoritative. Best-effort: failures must never affect opening the art.
  Future<void> cacheTouchedArtwork(PixelArt art) async {
    if (!art.id.startsWith('rmt_') || SplitArt.isPartId(art.id)) return;
    try {
      // The grid-string build + jsonEncode is tens of ms for a large grid;
      // this runs on the tap that starts the route transition, so keep it off
      // the UI isolate.
      final bytes = await compute(_encodeArtworkJson, art);
      await _storage.saveFile('remote_art_cache_${art.id}.json', bytes);
      _storage.addToStringSet(_cacheIndexKey, art.id);
    } catch (_) {}
  }

  static List<int> _encodeArtworkJson(PixelArt art) =>
      utf8.encode(jsonEncode(art.toJson()));

  /// Re-appends cached remote artworks that vanished from [catalog] but still
  /// carry user state (they join [retiredIds]); cache entries whose state is
  /// gone are deleted — the cache lives exactly as long as the state does.
  /// Callers run this on both fetch outcomes so offline launches are covered.
  Future<List<PixelArt>> withRestoredCachedArts(List<PixelArt> catalog) async {
    final cachedIds = _storage.getStringSet(_cacheIndexKey);
    if (cachedIds.isEmpty) return catalog;
    final presentIds = {for (final a in catalog) a.id};
    final rawJson = <String>[];
    for (final id in cachedIds) {
      if (presentIds.contains(id)) continue;
      // Cheap scalar pre-check: entries whose state is gone get deleted below
      // without ever paying the file read + full-grid parse.
      if (!_cachedIdHasState(id)) continue;
      try {
        final file = await _storage.getFile('remote_art_cache_$id.json');
        if (file != null) rawJson.add(await file.readAsString());
      } catch (_) {}
    }
    final restored = orphanedFromCache(rawJson, presentIds, _hasLocalState);
    final restoredIds = {for (final a in restored) a.id};
    _retiredIds.addAll(restoredIds);
    for (final id in cachedIds) {
      if (presentIds.contains(id) || restoredIds.contains(id)) continue;
      try {
        await _storage.deleteFile('remote_art_cache_$id.json');
      } catch (_) {}
      _storage.removeFromStringSet(_cacheIndexKey, id);
    }
    return restored.isEmpty ? catalog : [...catalog, ...restored];
  }

  /// Pure core of [withRestoredCachedArts]: which cached artworks should
  /// rejoin the catalog. Malformed entries are skipped (and thus cleaned up).
  static List<PixelArt> orphanedFromCache(
    Iterable<String> cachedJsonStrings,
    Set<String> presentIds,
    bool Function(PixelArt) hasState,
  ) {
    final restored = <PixelArt>[];
    for (final raw in cachedJsonStrings) {
      final PixelArt art;
      try {
        art = PixelArt.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        continue;
      }
      if (presentIds.contains(art.id)) continue;
      if (hasState(art)) restored.add(art);
    }
    return restored;
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
  ///  - bundled art: dropped when its override says `hidden` — unless its id
  ///    is in [keepHiddenIds] (user has local state on it, see [retiredIds]);
  ///    `isPremium` and `category` overridden when set; sortOrder = override
  ///    or manifest index
  ///  - remote art: dropped when not `visible`, outside its availability
  ///    window, gated behind a newer `minAppVersion` (schema features this
  ///    build can't render, e.g. split artworks), or carrying unusable split
  ///    metadata; sortOrder from the doc (default 0)
  ///  - sorted by sortOrder, insertion order as the tiebreak
  static List<PixelArt> mergeCatalog(
    List<PixelArt> bundled,
    List<Map<String, dynamic>> artworkDocs,
    Map<String, Map<String, dynamic>> overrides, {
    String? currentAppVersion,
    Set<String> keepHiddenIds = const {},
  }) {
    final entries = <(PixelArt, int, int)>[];

    for (var i = 0; i < bundled.length; i++) {
      final art = bundled[i];
      final o = overrides[art.id];
      if (o?['hidden'] == true && !keepHiddenIds.contains(art.id)) continue;
      final premium = o?['isPremium'] as bool?;
      final rawCategory = o?['category'] as String?;
      final diamondCost = (o?['diamondCost'] as num?)?.toInt();
      final category =
          (rawCategory == null || rawCategory.isEmpty) ? null : rawCategory;
      entries.add((
        (premium == null && category == null && diamondCost == null)
            ? art
            : art.copyWith(
                isPremium: premium,
                category: category,
                diamondCost: diamondCost,
              ),
        (o?['sortOrder'] as num?)?.toInt() ?? i,
        entries.length,
      ));
    }

    final now = DateTime.now();
    for (final data in artworkDocs) {
      if (data['visible'] == false) continue;
      final minVersion = data['minAppVersion'] as String?;
      if (minVersion != null &&
          currentAppVersion != null &&
          isVersionOlder(currentAppVersion, minVersion)) {
        continue;
      }
      final PixelArt art;
      try {
        art = PixelArt.fromJson(data);
      } catch (_) {
        continue; // One malformed doc must not take down the whole catalog.
      }
      // Malformed split metadata (dims not divisible, absurd tile count)
      // would break the part picker — drop the doc, not the app.
      if (art.isSplit && !SplitArt.validSplit(art)) continue;
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
