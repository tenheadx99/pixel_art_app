import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/flavor.dart';
import '../models/social_link.dart';
import 'local_storage_service.dart';

/// Manages dynamic social and web links for the app, synchronized from
/// Firestore (`pixel_art/{flavor}/config/social_links`) with real-time updates
/// and local cache fallback.
class SocialLinksService extends ChangeNotifier {
  static final SocialLinksService _instance = SocialLinksService._();
  factory SocialLinksService() => _instance;
  SocialLinksService._();

  static const String _storageKey = 'cached_social_links_config_v1';

  LocalStorageService? _storage;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  SocialLinksConfig _config = const SocialLinksConfig();

  SocialLinksConfig get config => _config;
  bool get isEnabled => _config.isEnabled;
  String get sectionTitle => _config.sectionTitle;

  /// Returns active, non-empty links sorted by order.
  List<SocialLink> get activeLinks {
    if (!isEnabled) return const [];
    final list = _config.links
        .where((l) => l.isEnabled && l.url.trim().isNotEmpty)
        .toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Attach [LocalStorageService] for caching.
  void attachStorage(LocalStorageService storage) {
    _storage = storage;
    _loadFromCache();
  }

  /// Loads locally cached configuration for instant offline availability.
  void _loadFromCache() {
    if (_storage == null) return;
    try {
      final raw = _storage!.getString(_storageKey);
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _config = SocialLinksConfig.fromMap(decoded);
          notifyListeners();
        }
      }
    } catch (e) {
      developer.log('SocialLinksService: error reading local cache: $e');
    }
  }

  /// Saves the current configuration to local storage cache.
  void _saveToCache() {
    if (_storage == null) return;
    try {
      final encoded = jsonEncode(_config.toMap());
      _storage!.setString(_storageKey, encoded);
    } catch (e) {
      developer.log('SocialLinksService: error saving local cache: $e');
    }
  }

  /// Initializes the service: loads local cache, fetches remote doc,
  /// and attaches real-time snapshot listener.
  Future<void> initialize({LocalStorageService? storage}) async {
    if (storage != null) {
      attachStorage(storage);
    } else {
      _loadFromCache();
    }

    final flavorId = currentFlavor.name;
    final docPath = 'pixel_art/$flavorId/config/social_links';

    // 1. Initial remote fetch
    try {
      final docRef = FirebaseFirestore.instance.doc(docPath);
      final snap = await docRef.get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.data() != null) {
        _applyRemoteData(snap.data()!);
      }
    } catch (e) {
      developer.log('SocialLinksService: initial fetch info/error: $e');
    }

    // 2. Real-time snapshot updates
    try {
      await _subscription?.cancel();
      final docRef = FirebaseFirestore.instance.doc(docPath);
      _subscription = docRef.snapshots().listen(
        (snap) {
          if (snap.exists && snap.data() != null) {
            _applyRemoteData(snap.data()!);
          }
        },
        onError: (e) {
          developer.log('SocialLinksService: snapshot error: $e');
        },
      );
    } catch (e) {
      developer.log('SocialLinksService: snapshot listen error: $e');
    }
  }

  void _applyRemoteData(Map<String, dynamic> data) {
    _config = SocialLinksConfig.fromMap(data);
    _saveToCache();
    notifyListeners();
  }

  /// Launches a social/web link safely in external application or browser.
  Future<bool> openLink(SocialLink link) async {
    final rawUrl = link.url.trim();
    if (rawUrl.isEmpty) return false;

    Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;

    // Ensure scheme is present
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$rawUrl');
      if (uri == null) return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      developer.log('SocialLinksService: external app launch failed for $uri: $e');
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      developer.log('SocialLinksService: platformDefault launch failed for $uri: $e');
      return false;
    }
  }

  /// Testing helper: direct local override.
  @visibleForTesting
  void updateConfigLocally(SocialLinksConfig newConfig) {
    _config = newConfig;
    _saveToCache();
    notifyListeners();
  }

  /// Testing helper: reset state.
  @visibleForTesting
  void resetForTesting() {
    _subscription?.cancel();
    _subscription = null;
    _config = const SocialLinksConfig();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

