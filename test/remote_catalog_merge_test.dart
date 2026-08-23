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

    test('a split doc survives the merge with its part layout', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [
          {...remoteDoc('rmt_split'), 'partsX': 2, 'partsY': 2},
        ],
        {},
      );
      final split = merged.firstWhere((a) => a.id == 'rmt_split');
      expect(split.isSplit, isTrue);
      expect(split.partCount, 4);
    });

    test('an admin-published portrait split doc (full field set) survives', () {
      // Exactly the map RemoteArtwork.toMap() writes in the admin panel for
      // an aspect-preset split artwork: PixelArt JSON + publish metadata.
      final portrait = PixelArt(
        id: 'rmt_krishna_1',
        name: 'Krishna',
        gridWidth: 6,
        gridHeight: 8,
        grid: List.generate(8, (_) => List.filled(6, 1)),
        colorMap: {1: const Color(0xFF2244AA)},
        category: 'Devotional',
        partsX: 3,
        partsY: 4,
      );
      final doc = {
        ...portrait.toJson(),
        'visible': true,
        'sortOrder': 0,
        'minAppVersion': '1.0.12',
      };
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [doc],
        {},
        currentAppVersion: '1.0.12',
      );
      final art = merged.firstWhere((a) => a.id == 'rmt_krishna_1');
      expect(art.gridWidth, 6);
      expect(art.gridHeight, 8);
      expect(art.partsX, 3);
      expect(art.partsY, 4);
    });

    test('minAppVersion docs are kept when the app version is unknown', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [
          {...remoteDoc('rmt_gated'), 'minAppVersion': '1.0.12'},
        ],
        {},
        currentAppVersion: null,
      );
      expect(ids(merged), contains('rmt_gated'));
    });

    test('a non-square split doc survives with its part layout', () {
      final portrait = PixelArt(
        id: 'rmt_portrait',
        name: 'p',
        gridWidth: 6,
        gridHeight: 8,
        grid: List.generate(8, (_) => List.filled(6, 1)),
        colorMap: {1: const Color(0xFF000000)},
        partsX: 3,
        partsY: 4,
      );
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [portrait.toJson()],
        {},
      );
      final art = merged.firstWhere((a) => a.id == 'rmt_portrait');
      expect(art.gridWidth, 6);
      expect(art.gridHeight, 8);
      expect(art.partCount, 12);
    });

    test('a split doc whose dims do not divide evenly is dropped', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [
          // 2x2 grid claiming a 3x3 split.
          {...remoteDoc('rmt_badsplit'), 'partsX': 3, 'partsY': 3},
          remoteDoc('rmt_ok'),
        ],
        {},
      );
      expect(ids(merged), contains('rmt_ok'));
      expect(ids(merged), isNot(contains('rmt_badsplit')));
    });

    test('keepHiddenIds retains a hidden bundled artwork with its overrides',
        () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [],
        {
          'b': {'hidden': true, 'isPremium': true},
        },
        keepHiddenIds: {'b'},
      );
      expect(ids(merged), ['a', 'b', 'c']);
      // Non-hidden override fields still apply to the retained artwork.
      expect(merged.firstWhere((x) => x.id == 'b').isPremium, isTrue);
    });

    test('keepHiddenIds does not resurrect other hidden artworks', () {
      final merged = RemoteCatalogService.mergeCatalog(
        bundled,
        [],
        {
          'a': {'hidden': true},
          'b': {'hidden': true},
        },
        keepHiddenIds: {'b'},
      );
      expect(ids(merged), ['b', 'c']);
    });

    test('minAppVersion gates docs for older app builds', () {
      final docs = [
        {...remoteDoc('rmt_gated'), 'minAppVersion': '1.0.12'},
        remoteDoc('rmt_open'),
      ];
      final older = RemoteCatalogService.mergeCatalog(
        bundled,
        docs,
        {},
        currentAppVersion: '1.0.11',
      );
      expect(ids(older), isNot(contains('rmt_gated')));
      expect(ids(older), contains('rmt_open'));

      final equal = RemoteCatalogService.mergeCatalog(
        bundled,
        docs,
        {},
        currentAppVersion: '1.0.12',
      );
      expect(ids(equal), contains('rmt_gated'));

      final newer = RemoteCatalogService.mergeCatalog(
        bundled,
        docs,
        {},
        currentAppVersion: '1.1.0',
      );
      expect(ids(newer), contains('rmt_gated'));
    });
  });

  group('RemoteCatalogService.replacementTargetId', () {
    final bundledIds = {'bird_01', 'cat_01'};

    test('explicit replaces field wins over id parsing', () {
      expect(
        RemoteCatalogService.replacementTargetId(
          {'id': 'rmt_totally_renamed_99', 'replaces': 'cat_01'},
          bundledIds,
        ),
        'cat_01',
      );
    });

    test('underscored slug parses from the rmt_<oldId>_<millis> convention',
        () {
      expect(
        RemoteCatalogService.replacementTargetId(
          {'id': 'rmt_bird_01_1712345678901'},
          bundledIds,
        ),
        'bird_01',
      );
    });

    test('a parsed id that is not bundled is rejected', () {
      expect(
        RemoteCatalogService.replacementTargetId(
          {'id': 'rmt_dog_01_1712345678901'},
          bundledIds,
        ),
        isNull,
      );
    });

    test('a bulk-import id without trailing millis does not misresolve', () {
      // `rmt_bird_01` parses as slug `bird` + digits `01`; `bird` is not a
      // bundled id, so no hand-off fires.
      expect(
        RemoteCatalogService.replacementTargetId(
          {'id': 'rmt_bird_01'},
          bundledIds,
        ),
        isNull,
      );
    });

    test('an unknown explicit replaces falls back to id parsing', () {
      expect(
        RemoteCatalogService.replacementTargetId(
          {'id': 'rmt_cat_01_99', 'replaces': 'zebra'},
          bundledIds,
        ),
        'cat_01',
      );
    });
  });

  group('RemoteCatalogService.orphanedFromCache', () {
    String json(String id) =>
        '{"id":"$id","name":"$id","gridWidth":2,"gridHeight":2,'
        '"grid":"1,0;0,1","colorMap":{"1":4278190080}}';

    test('restores a vanished artwork the user has state on', () {
      final restored = RemoteCatalogService.orphanedFromCache(
        [json('rmt_gone_1')],
        {'a', 'b'},
        (_) => true,
      );
      expect(ids(restored), ['rmt_gone_1']);
    });

    test('skips artworks still present in the catalog', () {
      final restored = RemoteCatalogService.orphanedFromCache(
        [json('rmt_here_1')],
        {'rmt_here_1'},
        (_) => true,
      );
      expect(restored, isEmpty);
    });

    test('skips artworks without local state', () {
      final restored = RemoteCatalogService.orphanedFromCache(
        [json('rmt_gone_1')],
        {},
        (_) => false,
      );
      expect(restored, isEmpty);
    });

    test('skips malformed cache entries', () {
      final restored = RemoteCatalogService.orphanedFromCache(
        ['not json', '{"id":"rmt_x"}', json('rmt_ok_1')],
        {},
        (_) => true,
      );
      expect(ids(restored), ['rmt_ok_1']);
    });
  });
}
