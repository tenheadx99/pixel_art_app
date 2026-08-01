import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/models/split_art.dart';

/// 6x6 parent split 3x3 (each part 2x2). The top-left tile is intentionally
/// empty (all background) and the middle-left tile has a single fillable cell,
/// so per-part fillable counts differ.
PixelArt splitParent({String id = 'rmt_parent'}) => PixelArt(
  id: id,
  name: 'Parent',
  gridWidth: 6,
  gridHeight: 6,
  grid: const [
    [0, 0, 1, 1, 2, 2],
    [0, 0, 1, 1, 2, 2],
    [3, 0, 1, 2, 3, 1],
    [0, 0, 2, 1, 1, 3],
    [1, 2, 3, 1, 2, 3],
    [3, 2, 1, 3, 2, 1],
  ],
  colorMap: const {
    1: Color(0xFFFF0000),
    2: Color(0xFF00FF00),
    3: Color(0xFF0000FF),
  },
  partsX: 3,
  partsY: 3,
);

void main() {
  group('PixelArt split fields', () {
    test('default is not split and serializes without part keys', () {
      final art = PixelArt(
        id: 'a',
        name: 'a',
        gridWidth: 2,
        gridHeight: 2,
        grid: const [
          [1, 0],
          [0, 1],
        ],
        colorMap: const {1: Color(0xFF000000)},
      );
      expect(art.isSplit, isFalse);
      final json = art.toJson();
      expect(json.containsKey('partsX'), isFalse);
      expect(json.containsKey('partsY'), isFalse);
      final back = PixelArt.fromJson(json);
      expect(back.partsX, 1);
      expect(back.partsY, 1);
    });

    test('split fields round-trip through JSON', () {
      final back = PixelArt.fromJson(splitParent().toJson());
      expect(back.partsX, 3);
      expect(back.partsY, 3);
      expect(back.isSplit, isTrue);
      expect(back.partCount, 9);
      expect(back.partWidth, 2);
      expect(back.partHeight, 2);
    });

    test('copyWith preserves split fields', () {
      final copy = splitParent().copyWith(category: 'Deities');
      expect(copy.partsX, 3);
      expect(copy.partsY, 3);
    });
  });

  group('SplitArt ids', () {
    test('partId round-trips through parentIdOf/partIndexOf', () {
      final id = SplitArt.partId('rmt_krishna_123', 7);
      expect(id, 'rmt_krishna_123_p7');
      expect(SplitArt.isPartId(id), isTrue);
      expect(SplitArt.parentIdOf(id), 'rmt_krishna_123');
      expect(SplitArt.partIndexOf(id), 7);
    });

    test('ordinary ids are not part ids', () {
      expect(SplitArt.isPartId('rmt_krishna_123'), isFalse);
      expect(SplitArt.isPartId('photo_1712'), isFalse);
      // '_p' followed by non-digits must not match.
      expect(SplitArt.isPartId('rmt_lotus_pond'), isFalse);
      expect(SplitArt.parentIdOf('rmt_krishna_123'), isNull);
    });
  });

  group('SplitArt.validSplit', () {
    test('accepts evenly divisible dims and non-split art', () {
      expect(SplitArt.validSplit(splitParent()), isTrue);
      final plain = PixelArt(
        id: 'a',
        name: 'a',
        gridWidth: 5,
        gridHeight: 5,
        grid: List.generate(5, (_) => List.filled(5, 1)),
        colorMap: const {1: Color(0xFF000000)},
      );
      expect(SplitArt.validSplit(plain), isTrue);
    });

    test('rejects dims that do not divide evenly', () {
      final bad = PixelArt(
        id: 'a',
        name: 'a',
        gridWidth: 5,
        gridHeight: 6,
        grid: List.generate(6, (_) => List.filled(5, 1)),
        colorMap: const {1: Color(0xFF000000)},
        partsX: 3,
        partsY: 3,
      );
      expect(SplitArt.validSplit(bad), isFalse);
    });

    test('rejects absurd tile counts', () {
      final bad = PixelArt(
        id: 'a',
        name: 'a',
        gridWidth: 64,
        gridHeight: 64,
        grid: List.generate(64, (_) => List.filled(64, 1)),
        colorMap: const {1: Color(0xFF000000)},
        partsX: 8,
        partsY: 8,
      );
      expect(SplitArt.validSplit(bad), isFalse);
    });
  });

  group('SplitArt.partOf', () {
    test('slices row-major tiles with the parent palette', () {
      final parent = splitParent();
      final p0 = SplitArt.partOf(parent, 0);
      expect(p0.id, 'rmt_parent_p0');
      expect(p0.gridWidth, 2);
      expect(p0.gridHeight, 2);
      expect(p0.grid, const [
        [0, 0],
        [0, 0],
      ]);
      expect(p0.colorMap, same(parent.colorMap));
      expect(p0.isSplit, isFalse);

      final p4 = SplitArt.partOf(parent, 4); // center tile: rows 2-3, cols 2-3
      expect(p4.grid, const [
        [1, 2],
        [2, 1],
      ]);

      final p8 = SplitArt.partOf(parent, 8); // bottom-right: rows 4-5, cols 4-5
      expect(p8.grid, const [
        [2, 3],
        [2, 1],
      ]);
      expect(p8.name, contains('Part 9/9'));
    });

    test('parts inherit catalog metadata', () {
      final parent = splitParent();
      final part = SplitArt.partOf(parent, 1);
      expect(part.category, parent.category);
      expect(part.difficulty, parent.difficulty);
      expect(part.isPremium, parent.isPremium);
    });
  });

  group('SplitArt.partFillableCounts', () {
    test('counts non-background cells per tile, row-major', () {
      expect(SplitArt.partFillableCounts(splitParent()), [
        0, 4, 4, // top row: empty tile, then two full tiles
        1, 4, 4, // middle row: single-cell tile
        4, 4, 4,
      ]);
    });
  });
}
