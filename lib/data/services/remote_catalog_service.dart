import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';

/// Manages downloading, caching, and serving dynamic artwork packs from remote CDNs.
class RemoteCatalogService {
  final LocalStorageService _storageService;
  final HttpClient _httpClient;

  RemoteCatalogService(this._storageService, [HttpClient? httpClient])
      : _httpClient = httpClient ?? HttpClient();

  static const String _manifestCacheKey = 'dynamic_catalog_manifest_v1';
  static const String _dynamicDirName = 'dynamic_artworks';

  Future<Directory> get _dynamicStorageDirectory async {
    final docsPath = await _storageService.documentsDir;
    final dir = Directory(p.join(docsPath, _dynamicDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads locally cached dynamic artworks from disk.
  Future<List<PixelArt>> getCachedDynamicArtworks() async {
    final artworks = <PixelArt>[];
    try {
      final dir = await _dynamicStorageDirectory;
      final files = dir.listSync();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json') && !entity.path.endsWith('manifest.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            artworks.add(PixelArt.fromJson(json));
          } catch (e) {
            developer.log('Failed to parse cached dynamic artwork: ${entity.path}', error: e);
          }
        }
      }
    } catch (e, st) {
      developer.log('Error reading cached dynamic artworks', error: e, stackTrace: st);
    }
    return artworks;
  }

  /// Downloads a remote manifest JSON and updates local disk cache with new dynamic artwork items.
  Future<List<PixelArt>> fetchRemoteCatalog(String manifestUrl) async {
    if (manifestUrl.isEmpty) return getCachedDynamicArtworks();

    try {
      final request = await _httpClient.getUrl(Uri.parse(manifestUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final rawManifest = jsonDecode(body) as List<dynamic>;

        final dir = await _dynamicStorageDirectory;
        final downloadedArtworks = <PixelArt>[];

        for (final item in rawManifest) {
          if (item is Map<String, dynamic>) {
            try {
              final art = PixelArt.fromJson(item);
              final filePath = p.join(dir.path, '${art.id}.json');
              final file = File(filePath);
              await file.writeAsString(jsonEncode(item));
              downloadedArtworks.add(art);
            } catch (e) {
              developer.log('Failed to ingest dynamic item', error: e);
            }
          }
        }

        // Cache the raw manifest string metadata for offline fallback
        _storageService.setString(_manifestCacheKey, body);
        return downloadedArtworks;
      }
    } catch (e, st) {
      developer.log('Failed to fetch remote catalog from $manifestUrl, falling back to disk cache', error: e, stackTrace: st);
    }

    return getCachedDynamicArtworks();
  }

  /// Clears all downloaded dynamic artworks from disk cache.
  Future<void> clearDynamicCache() async {
    try {
      final dir = await _dynamicStorageDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _storageService.setString(_manifestCacheKey, '');
    } catch (e) {
      developer.log('Failed to clear dynamic catalog cache', error: e);
    }
  }
}
