import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';

/// Set `--dart-define=SHOW_DRAFT_ART=true` on a debug build to also fetch
/// draft (visible == false) artworks — lets you proof unpublished art on a
/// real device before making it live.
const bool kShowDraftArt = bool.fromEnvironment('SHOW_DRAFT_ART');

/// Result of a catalog sync: the merged catalog plus the admin-scheduled
/// Daily Pixel artwork id for today (null = use the default rotation).
class RemoteCatalogResult {
  final List<PixelArt> catalog;
  final String? scheduledDailyArtId;

  const RemoteCatalogResult({
    required this.catalog,
    this.scheduledDailyArtId,
  });
}

/// Admin-published catalog data from Firestore (written by the separate
/// pixel_art_admin project), merged over the bundled assets:
///
/// - `pixel_art/{flavor}/artworks`       — NEW artworks (ids prefixed `rmt_`)
/// - `pixel_art/{flavor}/overrides`      — sparse metadata/order overrides
///   for BUNDLED art (hidden / isPremium / category / sortOrder)
/// - `pixel_art/{flavor}/daily_schedule` — optional per-date Daily Pixel pick
///
/// The flavor root doc's `catalogVersion` is bumped by every admin mutation;
/// the full catalog is only refetched when it exceeds the cached version, so
/// the steady-state launch cost is two document reads (version + today's
/// schedule). The last-synced state is cached as JSON in the app support dir,
/// so offline launches keep the remote art. Everything here is non-fatal: on
/// any failure the app just shows the bundled catalog, exactly as before.
class RemoteCatalogService {
  static final RemoteCatalogService _instance = RemoteCatalogService._();
  factory RemoteCatalogService() => _instance;
  RemoteCatalogService._();

  static const _root = 'pixel_art';
  static const _syncTimeout = Duration(seconds: 15);

  DocumentReference<Map<String, dynamic>> get _flavorRef =>
      FirebaseFirestore.instance.collection(_root).doc(currentFlavor.name);

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/remote_catalog_${currentFlavor.name}.json');
  }

  /// Merges [bundled] with the cached remote state immediately, then checks
  /// Firestore and refetches if the admin published anything new. Calls
  /// [onResult] with the merged catalog (once from cache if present, and
  /// again when fresher data or today's daily schedule arrives).
  Future<void> loadAndSync(
    List<PixelArt> bundled,
    void Function(RemoteCatalogResult result) onResult,
  ) async {
    _CachedCatalog? cached;
    try {
      cached = await _readCache();
      if (cached != null) {
        onResult(RemoteCatalogResult(catalog: _merge(bundled, cached)));
      }
    } catch (e) {
      developer.log('Remote catalog cache unreadable, ignoring: $e');
    }

    try {
      final results = await Future.wait([
        _flavorRef.get(),
        _flavorRef.collection('daily_schedule').doc(_todayKey()).get(),
      ]).timeout(_syncTimeout);
      final flavorDoc = results[0];
      final scheduledId = results[1].data()?['artId'] as String?;

      final version = (flavorDoc.data()?['catalogVersion'] as num?)?.toInt();
      if (version == null) {
        // Flavor not seeded yet — bundled only, but the schedule still counts.
        if (scheduledId != null) {
          onResult(RemoteCatalogResult(
            catalog: cached != null ? _merge(bundled, cached) : bundled,
            scheduledDailyArtId: scheduledId,
          ));
        }
        return;
      }

      var latest = cached;
      if (latest == null || version > latest.version) {
        latest = await _fetchRemote(version);
        await _writeCache(latest);
        developer.log(
          'Remote catalog synced v$version: ${latest.artworks.length} '
          'artworks, ${latest.overrides.length} overrides',
        );
      }
      onResult(RemoteCatalogResult(
        catalog: _merge(bundled, latest),
        scheduledDailyArtId: scheduledId,
      ));
    } catch (e) {
      developer.log('Remote catalog sync failed (bundled catalog stays): $e');
    }
  }

  Future<_CachedCatalog> _fetchRemote(int version) async {
    // Drafts (visible == false) are only fetched with the debug define.
    Query<Map<String, dynamic>> artworksQuery = _flavorRef.collection('artworks');
    if (!kShowDraftArt) {
      artworksQuery = artworksQuery.where('visible', isEqualTo: true);
    }
    final artworksSnap = await artworksQuery.get().timeout(_syncTimeout);
    final overridesSnap =
        await _flavorRef.collection('overrides').get().timeout(_syncTimeout);

    // Keep raw JSON-safe maps: Firestore Timestamps (createdAt/updatedAt)
    // are not JSON-encodable and would corrupt the cache.
    final artworks = <Map<String, dynamic>>[
      for (final doc in artworksSnap.docs)
        {
          for (final entry in doc.data().entries)
            if (entry.value is! Timestamp) entry.key: entry.value,
        },
    ];

    final overrides = <String, Map<String, dynamic>>{
      for (final doc in overridesSnap.docs)
        doc.id: {
          if (doc.data()['hidden'] is bool) 'hidden': doc.data()['hidden'],
          if (doc.data()['isPremium'] is bool)
            'isPremium': doc.data()['isPremium'],
          if (doc.data()['category'] is String)
            'category': doc.data()['category'],
          if (doc.data()['sortOrder'] is num)
            'sortOrder': (doc.data()['sortOrder'] as num).toInt(),
        },
    };

    return _CachedCatalog(
      version: version,
      artworks: artworks,
      overrides: overrides,
    );
  }

  /// Applies admin overrides to the bundled list and merges in remote
  /// artworks: hidden pieces are dropped, availability windows are enforced,
  /// and the combined list is ordered by admin sortOrder (bundled art
  /// defaults to its manifest position, remote art to the end).
  List<PixelArt> _merge(List<PixelArt> bundled, _CachedCatalog remote) {
    final now = DateTime.now();
    final bundledIds = {for (final art in bundled) art.id};
    final entries = <({PixelArt art, int sort})>[];

    for (var i = 0; i < bundled.length; i++) {
      final art = bundled[i];
      final override = remote.overrides[art.id];
      if (override == null) {
        entries.add((art: art, sort: i));
        continue;
      }
      if (override['hidden'] == true) continue;
      entries.add((
        art: art.copyWith(
          category: override['category'] as String?,
          isPremium: override['isPremium'] as bool?,
        ),
        sort: (override['sortOrder'] as int?) ?? i,
      ));
    }

    for (var i = 0; i < remote.artworks.length; i++) {
      final raw = remote.artworks[i];
      if (raw['visible'] == false && !kShowDraftArt) continue;
      PixelArt art;
      try {
        art = PixelArt.fromJson(raw);
      } catch (e) {
        developer.log('Skipping malformed remote artwork ${raw['id']}: $e');
        continue;
      }
      if (bundledIds.contains(art.id)) continue; // Bundled always wins.
      if (!art.isAvailableAt(now)) continue; // Seasonal window closed.
      entries.add((
        art: art,
        sort: (raw['sortOrder'] as num?)?.toInt() ?? bundled.length + i,
      ));
    }

    entries.sort((a, b) => a.sort.compareTo(b.sort));
    return [for (final e in entries) e.art];
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<_CachedCatalog?> _readCache() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return _CachedCatalog(
      version: json['version'] as int,
      artworks: [
        for (final art in json['artworks'] as List)
          (art as Map).cast<String, dynamic>(),
      ],
      overrides: {
        for (final entry in (json['overrides'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as Map).cast<String, dynamic>(),
      },
    );
  }

  Future<void> _writeCache(_CachedCatalog catalog) async {
    final file = await _cacheFile();
    // Write-then-rename so a crash mid-write can't corrupt the cache.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': catalog.version,
      'artworks': catalog.artworks,
      'overrides': catalog.overrides,
    }));
    await tmp.rename(file.path);
  }
}

class _CachedCatalog {
  final int version;
  final List<Map<String, dynamic>> artworks;
  final Map<String, Map<String, dynamic>> overrides;

  const _CachedCatalog({
    required this.version,
    required this.artworks,
    required this.overrides,
  });
}
