import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/coloring_provider.dart';

PixelArt _testArt() => PixelArt(
  id: 'test_art',
  name: 'Test',
  gridWidth: 2,
  gridHeight: 2,
  grid: [
    [1, 1],
    [1, 0],
  ],
  colorMap: {1: Color(0xFFFF0000)},
);

Future<ColoringProvider> _providerWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = LocalStorageService();
  await storage.init();
  return ColoringProvider(storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('magic wand persistence', () {
    test('fresh install grants 5 wands', () async {
      final provider = await _providerWith({});
      provider.loadArt(_testArt());
      expect(provider.magicWandsCount, 5);
    });

    test('a stored count of 0 stays 0 instead of refilling', () async {
      final provider = await _providerWith({'magic_wands_count': 0});
      provider.loadArt(_testArt());
      expect(provider.magicWandsCount, 0);
    });

    test('a stored positive count is restored', () async {
      final provider = await _providerWith({'magic_wands_count': 2});
      provider.loadArt(_testArt());
      expect(provider.magicWandsCount, 2);
    });
  });

  group('auto-advance', () {
    PixelArt twoColorArt() => PixelArt(
      id: 'two_color',
      name: 'Two Color',
      gridWidth: 2,
      gridHeight: 2,
      grid: [
        [1, 2],
        [2, 2],
      ],
      colorMap: {1: Color(0xFFFF0000), 2: Color(0xFF00FF00)},
    );

    test('selection moves to the next number when one completes', () async {
      final provider = await _providerWith({});
      provider.loadArt(twoColorArt());
      provider.selectNumber(1);
      provider.tryFillCell(0, 0); // last (only) cell of number 1
      expect(provider.selectedNumber, 2);
    });

    test('drag stroke groups into a single undo entry', () async {
      final provider = await _providerWith({});
      provider.loadArt(twoColorArt());
      provider.selectNumber(2);
      provider.beginStroke();
      provider.strokeFill(0, 1);
      provider.strokeFill(1, 0);
      provider.strokeFill(1, 1);
      provider.endStroke();
      expect(provider.filledGrid[1][1], 2);
      provider.undo();
      expect(provider.filledGrid[0][1], 0);
      expect(provider.filledGrid[1][0], 0);
      expect(provider.filledGrid[1][1], 0);
    });

    test('hint fills one correct cell and selects its number', () async {
      final provider = await _providerWith({});
      provider.loadArt(twoColorArt());
      provider.selectNumber(1);
      provider.tryFillCell(0, 0); // number 1 done, auto-advance to 2
      final target = provider.applyHint();
      expect(target, isNotNull);
      expect(provider.filledGrid[target!.$1][target.$2], 2);
      expect(provider.selectedNumber, 2);
    });

    test('undo reverts timeLapse entries for filled cells', () async {
      final provider = await _providerWith({});
      provider.loadArt(twoColorArt());
      provider.selectNumber(2);
      expect(provider.timeLapse.length, 0);
      provider.tryFillCell(0, 1);
      expect(provider.timeLapse.length, 1);
      provider.undo();
      expect(provider.timeLapse.length, 0);
    });
  });

  group('ASMR sounds and section completion callbacks', () {
    test('onCellFilledCorrectly is called when a cell is colored', () async {
      final provider = await _providerWith({});
      provider.loadArt(_testArt());
      provider.selectNumber(1);

      int cellFilledCalls = 0;
      provider.onCellFilledCorrectly = () {
        cellFilledCalls++;
      };

      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(cellFilledCalls, 1);
    });

    test('onSectionCompleted is called when the color group completes', () async {
      final provider = await _providerWith({});
      provider.loadArt(_testArt());
      provider.selectNumber(1);

      int sectionCompletedCalls = 0;
      provider.onSectionCompleted = () {
        sectionCompletedCalls++;
      };

      // _testArt has three cells of number 1: (0,0), (0,1), and (1,0)
      provider.tryFillCell(0, 0);
      provider.tryFillCell(0, 1);
      expect(sectionCompletedCalls, 0); // Not completed yet

      provider.tryFillCell(1, 0);
      expect(sectionCompletedCalls, 1); // Now completed!
    });
  });

  group('other fill tools (magic wand, bomb, erase)', () {
    PixelArt largerTestArt() => PixelArt(
      id: 'larger_test',
      name: 'Larger Test',
      gridWidth: 3,
      gridHeight: 3,
      grid: [
        [1, 1, 2],
        [1, 0, 2],
        [2, 1, 1],
      ],
      colorMap: {1: Color(0xFFFF0000), 2: Color(0xFF0000FF)},
    );

    test('magic wand fills connected region of same number and decrements wand count', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      expect(provider.magicWandsCount, 5);

      provider.toggleMagicWandMode();
      expect(provider.isMagicWandMode, isTrue);

      // Tap (0, 0), which has number 1
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(provider.isMagicWandMode, isFalse);
      expect(provider.magicWandsCount, 4);

      // (0,0), (0,1), (1,0) are connected and should be filled
      expect(provider.filledGrid[0][0], 1);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[1][0], 1);

      // (2,1) and (2,2) are also 1 but not connected, so they should not be filled
      expect(provider.filledGrid[2][1], 0);
      expect(provider.filledGrid[2][2], 0);
    });

    test('bomb fills all non-zero cells in a 3x3 region and decrements bomb count', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      expect(provider.bombsCount, 5);

      provider.toggleBombMode();
      expect(provider.isBombMode, isTrue);

      // Tap at the center (1, 1)
      final success = provider.tryFillCell(1, 1);
      expect(success, isTrue);
      expect(provider.isBombMode, isFalse);
      expect(provider.bombsCount, 4);

      // All non-zero cells in the grid should be filled
      expect(provider.filledGrid[0][0], 1);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[0][2], 2);
      expect(provider.filledGrid[1][0], 1);
      expect(provider.filledGrid[1][1], 0); // (1, 1) is 0 in the art grid
      expect(provider.filledGrid[1][2], 2);
      expect(provider.filledGrid[2][0], 2);
      expect(provider.filledGrid[2][1], 1);
      expect(provider.filledGrid[2][2], 1);
    });

    test('erase mode sets filled cell back to 0', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      provider.selectNumber(1);

      // Fill a cell
      provider.tryFillCell(0, 0);
      expect(provider.filledGrid[0][0], 1);

      // Toggle erase mode
      provider.toggleEraseMode();
      expect(provider.isEraseMode, isTrue);

      // Erase the cell
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(provider.filledGrid[0][0], 0);
    });

    test('single tap on another color cell auto-selects that color and fills cell correctly', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      provider.selectNumber(1);
      expect(provider.selectedNumber, 1);

      // Tap cell (0, 2) which has number 2
      final success = provider.tryFillCell(0, 2);
      expect(success, isTrue);
      expect(provider.selectedNumber, 2);
      expect(provider.filledGrid[0][2], 2);
    });
  });
}
