import 'dart:async';
import 'dart:developer' as developer;
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:pixel_art_app/data/services/notification_service.dart';

/// Manages incoming App Links (verified HTTPS URLs) and custom URI schemes
/// (`pixely://`), routing deep-link payloads to the appropriate in-app destination.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  static DeepLinkService get instance => _instance;
  DeepLinkService._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;

  /// Starts listening to incoming deep links and processes any link that
  /// launched the application cold.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _appLinks = AppLinks();

      // 1. Check for initial link when the app cold boots from a tapped URL
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        developer.log('DeepLinkService: initial link received: $initialUri');
        handleUri(initialUri);
      }

      // 2. Listen to subsequent links while the app is in foreground or background
      _linkSub = _appLinks!.uriLinkStream.listen(
        (uri) {
          developer.log('DeepLinkService: incoming link received: $uri');
          handleUri(uri);
        },
        onError: (err) {
          developer.log('DeepLinkService: stream error: $err');
        },
      );
    } catch (e, stack) {
      developer.log(
        'DeepLinkService: initialization failed: $e',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Parses a deep-link URI and routes it to the corresponding destination
  /// via [NotificationService] action notifiers.
  @visibleForTesting
  void handleUri(Uri uri) {
    try {
      final path = uri.path.toLowerCase();
      final host = uri.host.toLowerCase();
      final params = uri.queryParameters;

      // Case 1: Specific artwork ID (?id=artwork_123 or /art/artwork_123)
      final artId = params['id'] ??
          (path.startsWith('/art/') && uri.pathSegments.length >= 2
              ? uri.pathSegments[1]
              : null);

      if (artId != null && artId.trim().isNotEmpty) {
        NotificationService.instance.pendingArtworkId.value = artId.trim();
        return;
      }

      // Case 2: Daily Art (/daily or ?type=daily)
      if (path.contains('daily') || host == 'daily' || params['type'] == 'daily') {
        NotificationService.instance.dailyArtRequested.value = true;
        return;
      }

      // Case 3: Category filter (?category=Animals or /category/Animals)
      final category = params['category'] ??
          (path.startsWith('/category/') && uri.pathSegments.length >= 2
              ? uri.pathSegments[1]
              : null);

      if (category != null && category.trim().isNotEmpty) {
        NotificationService.instance.pendingCategory.value = category.trim();
        return;
      }

      // Case 4: Shop (?type=shop or /shop)
      if (path.contains('shop') || host == 'shop' || params['type'] == 'shop') {
        NotificationService.instance.pendingShopRequested.value = true;
        return;
      }
    } catch (e) {
      developer.log('DeepLinkService: error handling URI $uri: $e');
    }
  }

  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    _initialized = false;
  }
}
