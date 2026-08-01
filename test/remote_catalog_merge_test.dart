import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/remote_catalog_service.dart';

PixelArt art(String id, {String category = 'General', bool premium = false}) {
  return PixelArt(
    id: id,
    name: id,
    gridWidth: 2,
    gridHeight: 2,
    grid: [
      [1, 0],
      [0, 1],
    ],
    colorMap: {1: const Color(0xFF000000)},
    category: category,
    isPremium: premium,
  );
}

/// A remote artwork doc as the admin panel writes it (PixelArt JSON +
/// `visible` + `sortOrder`).
Map<String, dynamic> remoteDoc(
  String id, {
  bool? visible,
  int? sortOrder,
  String? availableFrom,
  String? availableUntil,
}) {
  return {
    ...art(id).toJson(),
    'visible': ?visible,
    'sortOrder': ?sortOrder,
    'availableFrom': ?availableFrom,
    'availableUntil': ?availableUntil,
  };
}

List<String> ids(List<PixelArt> arts) => [for (final a in arts) a.id];

void main() {
  group('RemoteCatalogService.mergeCatalog', () {
    final bundled = [art('a'), art('b'), art('c')];

    test('no remote data keeps the bundled catalog in manifest order', () {
      final merged = RemoteCatalogService.mergeCatalog(bundled, [], {});
      expect(ids(merged), ['a', 'b', 'c']);
    });

    test('hidden override drops a bundled artwork', () {
      final merged = RemoteCatalogService.mergeCatalog(bundled, [], {
        'b': {'hidden': true},
      });
      expect(ids(merged), ['a', 'c']);
    });

    test('overrides replace isPremium and category, keep grid identity', () {
      final merged = RemoteCatalogService.mergeCatalog(bundled, [], {
        'a': {'isPremium': true, 'category': 'Seasonal'},
      });
      final a = merged.firstWhere((x) => x.id == 'a');
      expect(a.isPremium, isTrue);
      expect(a.category, 'Seasonal');
      expect(a.grid, bundled[0].grid);
      // Empty category string means "not overridden".
      final merged2 = RemoteCatalogService.mergeCatalog(bundled, [], {
        'a': {'category': ''},
      });
      expect(merged2.firstWhere((x) => x.id == 'a').category, 'General');
    });

    test('sortOrder from overrides and remote docs interleaves the list', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [remoteDoc('rmt_x', sortOrder: 1)],
        {
          'a': {'sortOrder': 5},
        },
      );
      // b=1(manifest), rmt_x=1 (after b: insertion tiebreak), c=2, a=5.
      expect(ids(merged), ['b', 'rmt_x', 'c', 'a']);
    });

    test('invisible (draft) remote artworks are excluded', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [remoteDoc('rmt_x', visible: false), remoteDoc('rmt_y', visible: true)],
        {},
      );
      expect(ids(merged), contains('rmt_y'));
      expect(ids(merged), isNot(contains('rmt_x')));
    });

    test('availability window filters remote artworks', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [
          remoteDoc('rmt_future', availableFrom: '2999-01-01T00:00:00.000'),
          remoteDoc('rmt_past', availableUntil: '2000-01-01T00:00:00.000'),
          remoteDoc(
            'rmt_open',
            availableFrom: '2000-01-01T00:00:00.000',
            availableUntil: '2999-01-01T00:00:00.000',
          ),
        ],
        {},
      );
      expect(ids(merged), contains('rmt_open'));
      expect(ids(merged), isNot(contains('rmt_future')));
      expect(ids(merged), isNot(contains('rmt_past')));
    });

    test('a malformed remote doc is skipped, not fatal', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [
          {'id': 'rmt_broken', 'name': 'x'}, // no grid/colorMap
          remoteDoc('rmt_ok'),
        ],
        {},
      );
      expect(ids(merged), contains('rmt_ok'));
      expect(ids(merged), isNot(contains('rmt_broken')));
    });
  });
}
