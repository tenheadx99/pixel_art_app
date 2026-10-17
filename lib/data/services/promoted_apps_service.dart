import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/flavor.dart';
import '../models/promoted_app.dart';
import 'local_storage_service.dart';

class PromotedAppsService {
  final LocalStorageService _storage;

  PromotedAppsService(this._storage);

  static const String _collectionPath = 'pixel_art/common/promoted_apps';
  static const String _cacheKey = 'cached_promoted_apps_json';

  /// Fetches the list of promoted apps from Firestore (with local cache & flavor fallback).
  Future<List<PromotedApp>> getPromotedApps() async {
    final currentFlavorName = currentFlavor.name;

    // 1. Try to fetch from Firestore with a short timeout so app never hangs
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db
          .collection(_collectionPath)
          .where('enabled', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 4));

      if (snap.docs.isNotEmpty) {
        final docsData = <Map<String, dynamic>>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (!data.containsKey('id') || (data['id'] as String).isEmpty) {
            data['id'] = d.id;
          }
          docsData.add(data);
        }

        // Cache for offline resilience
        try {
          _storage.setString(_cacheKey, jsonEncode(docsData));
        } catch (_) {}

        final apps = <PromotedApp>[];
        for (final item in docsData) {
          try {
            apps.add(PromotedApp.fromJson(item));
          } catch (e) {
            debugPrint('PromotedAppsService: error parsing app: $e');
          }
        }
        if (apps.isNotEmpty) {
          return _filterAndSort(apps, currentFlavorName);
        }
      }
    } catch (e) {
      debugPrint('PromotedAppsService: Firestore fetch failed ($e), checking cache...');
    }

    // 2. Fall back to cached JSON
    final cached = _storage.getString(_cacheKey);
    if (cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        final apps = <PromotedApp>[];
        for (final item in list) {
          try {
            final app = PromotedApp.fromJson(item as Map<String, dynamic>);
            if (app.enabled) apps.add(app);
          } catch (_) {}
        }
        if (apps.isNotEmpty) {
          return _filterAndSort(apps, currentFlavorName);
        }
      } catch (_) {}
    }

    // 3. Fall back to built-in sibling flavors
    return _buildFlavorFallbacks(currentFlavorName);
  }

  /// Filters out the current flavor and sorts by sortOrder.
  List<PromotedApp> _filterAndSort(List<PromotedApp> apps, String activeFlavor) {
    final filtered = apps.where((app) {
      // Never promote the app the user is already inside
      if (app.id.toLowerCase() == activeFlavor.toLowerCase()) {
        return false;
      }

      // Check flavor targeting
      final targets = app.targetFlavors.map((t) => t.toLowerCase()).toList();
      if (targets.contains('all') || targets.contains(activeFlavor.toLowerCase())) {
        return true;
      }
      return false;
    }).toList();

    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filtered;
  }

  /// Generates fallback showcase from other app flavors in the codebase.
  List<PromotedApp> _buildFlavorFallbacks(String activeFlavor) {
    final list = <PromotedApp>[];
    int order = 0;

    for (final flavor in AppFlavor.values) {
      if (flavor.name == activeFlavor) continue;
      final cfg = FlavorConfig.of(flavor);

      String? badge;
      if (flavor == AppFlavor.stitch) badge = 'NEW';
      if (flavor == AppFlavor.anime || flavor == AppFlavor.diamond) badge = 'HOT';
      if (flavor == AppFlavor.devotional) badge = 'POPULAR';

      final packageName = switch (flavor) {
        AppFlavor.original => 'com.tenhead.pixelyart',
        AppFlavor.devotional => 'com.tenhead.divinepixels',
        AppFlavor.anime => 'com.tenhead.animepixels',
        AppFlavor.pixelcalm => 'com.tenhead.pixelcalm',
        AppFlavor.diamond => 'com.tenhead.gemart',
        AppFlavor.bible => 'com.tenhead.bible',
        AppFlavor.stitch => 'com.tenhead.craftcolor',
      };

      list.add(
        PromotedApp(
          id: flavor.name,
          title: cfg.appName,
          tagline: cfg.splashTagline,
          packageName: packageName,
          iconUrl: cfg.appIconPath,
          badge: badge,
          rating: 4.8,
          downloadCount: '50K+',
          sortOrder: order++,
          enabled: true,
          targetFlavors: const ['all'],
        ),
      );
    }

    return list;
  }

  /// Launches the Play Store (or App Store) page for the app.
  static Future<bool> openAppStore(PromotedApp app) async {
    final Uri marketUri = Uri.parse('market://details?id=${app.packageName}');
    final Uri webUri = Uri.parse(app.effectivePlayStoreUrl);

    try {
      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return false;
  }
}
