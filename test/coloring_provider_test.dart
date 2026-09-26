import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/coloring_provider.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

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
    test('fresh install grants 3 wands', () async {
      final provider = await _providerWith({});
      provider.loadArt(_testArt());
      expect(provider.magicWandsCount, 3);
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

    test('cycleNextFillable cycles through unfilled cells for selected number', () async {
      final provider = await _providerWith({});
      provider.loadArt(twoColorArt());
      provider.selectNumber(2);
      expect(provider.nextFillable, (0, 1));
      final next1 = provider.cycleNextFillable();
      expect(next1, (1, 0));
      expect(provider.nextFillable, (1, 0));
      final next2 = provider.cycleNextFillable();
      expect(next2, (1, 1));
      expect(provider.nextFillable, (1, 1));
      final next3 = provider.cycleNextFillable();
      expect(next3, (0, 1)); // cycles back to start
      expect(provider.nextFillable, (0, 1));
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

  group('mismatched save discard', () {
    const k = 'pixelart_progress_test_art';
    const threeByThree = '1,1,1;1,1,1;1,1,1';

    test('a dimension-mismatched save is backed up and fully zeroed',
        () async {
      final provider = await _providerWith({
        k: threeByThree, // 3x3 save for a 2x2 artwork
        '${k}_pct': 60,
        '${k}_ts': 1234,
        '${k}_fills': 9,
        '${k}_erases': 2,
        '${k}_timelapse': '0,0;1,1',
        '${k}_milestones': '30',
      });
      await provider.loadArt(_testArt());

      final prefs = await SharedPreferences.getInstance();
      // No phantom progress left for home/gallery to display...
      expect(prefs.getInt('${k}_pct'), 0);
      expect(prefs.getString(k), isEmpty);
      expect(prefs.getInt('${k}_ts'), 0);
      expect(prefs.getInt('${k}_fills'), 0);
      expect(prefs.getInt('${k}_erases'), 0);
      expect(prefs.getString('${k}_timelapse'), isEmpty);
      expect(prefs.getString('${k}_milestones'), isEmpty);
      // ...but the raw grid survives as manual-recovery insurance in the
      // single rolling backup slot.
      expect(
        prefs.getString('pixelart_last_discarded_save'),
        'test_art|$threeByThree',
      );
      expect(provider.progress, 0);
    });

    test('a column-count mismatch discards too', () async {
      final provider = await _providerWith({
        k: '1,1,1;1,1,1', // 2 rows x 3 cols for a 2x2 artwork
        '${k}_pct': 40,
      });
      await provider.loadArt(_testArt());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('${k}_pct'), 0);
      expect(
        prefs.getString('pixelart_last_discarded_save'),
        'test_art|1,1,1;1,1,1',
      );
    });

    test('a fresh save round-trips after the discard', () async {
      final provider = await _providerWith({k: threeByThree, '${k}_pct': 60});
      await provider.loadArt(_testArt());
      provider.selectNumber(1);
      provider.tryFillCell(0, 0);
      await provider.saveProgress();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(k), isNotEmpty);
      final reloaded = await _providerWith(
        Map.fromEntries(
          prefs.getKeys().map((key) => MapEntry(key, prefs.get(key)!)),
        ),
      );
      await reloaded.loadArt(_testArt());
      expect(reloaded.filledGrid[0][0], 1);
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

    test('magic wand fills all cells of same number across artwork and decrements wand count', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      expect(provider.magicWandsCount, 3);

      provider.toggleMagicWandMode();
      expect(provider.isMagicWandMode, isTrue);

      // Tap (0, 0), which has number 1
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(provider.isMagicWandMode, isFalse);
      expect(provider.magicWandsCount, 2);

      // (0,0), (0,1), (1,0) are 1 and should be filled
      expect(provider.filledGrid[0][0], 1);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[1][0], 1);

      // (2,1) and (2,2) are also 1 across the artwork and should also be filled!
      expect(provider.filledGrid[2][1], 1);
      expect(provider.filledGrid[2][2], 1);
    });

    test('magic wand triggers onWaveFill with concentric distance rings across entire artwork', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());

      List<List<(int, int)>>? capturedRings;
      WaveFillType? capturedType;
      int? capturedCenterR;
      int? capturedCenterC;

      provider.onWaveFill = (r, c, rings, type) {
        capturedCenterR = r;
        capturedCenterC = c;
        capturedRings = rings;
        capturedType = type;
      };

      provider.toggleMagicWandMode();
      provider.tryFillCell(0, 0);

      expect(capturedType, WaveFillType.magicWand);
      expect(capturedCenterR, 0);
      expect(capturedCenterC, 0);
      expect(capturedRings, isNotNull);
      expect(capturedRings!.length, greaterThanOrEqualTo(3));
      // Ring 0 is the starting cell
      expect(capturedRings![0], [(0, 0)]);
      // Ring 1 contains distance-1 cells
      expect(capturedRings![1], containsAll([(0, 1), (1, 0)]));
      // Ring 2 contains farther cells across the artwork
      expect(capturedRings![2], containsAll([(2, 1), (2, 2)]));
    });

    test('magic wand flows through already-filled cells in a connected component', () async {
      final grid3x3 = [
        [1, 1, 1],
        [0, 0, 0],
        [0, 0, 0],
      ];
      final art = PixelArt(
        id: 'art_strip',
        name: 'Strip',
        gridWidth: 3,
        gridHeight: 3,
        grid: grid3x3,
        colorMap: {1: const Color(0xFFFF0000)},
      );
      final provider = await _providerWith({});
      provider.loadArt(art);

      // Pre-fill the middle cell (0, 1)
      provider.tryFillCell(0, 1);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[0][0], 0);
      expect(provider.filledGrid[0][2], 0);

      // Tap (0, 0) with magic wand: should fill both (0, 0) and through (0, 1) to (0, 2)
      provider.toggleMagicWandMode();
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(provider.filledGrid[0][0], 1);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[0][2], 1);
    });

    test('magic wand works when tapping an already-filled cell with unfilled neighbors', () async {
      final grid3x3 = [
        [1, 1, 1],
        [0, 0, 0],
        [0, 0, 0],
      ];
      final art = PixelArt(
        id: 'art_strip',
        name: 'Strip',
        gridWidth: 3,
        gridHeight: 3,
        grid: grid3x3,
        colorMap: {1: const Color(0xFFFF0000)},
      );
      final provider = await _providerWith({});
      provider.loadArt(art);

      // Pre-fill cell (0, 0)
      provider.tryFillCell(0, 0);
      expect(provider.filledGrid[0][0], 1);
      expect(provider.filledGrid[0][1], 0);

      // Tap (0, 0) with magic wand: should flood fill connected unfilled cells (0, 1) and (0, 2)
      provider.toggleMagicWandMode();
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      expect(provider.filledGrid[0][1], 1);
      expect(provider.filledGrid[0][2], 1);
    });

    test('magic wand completes target number across artwork and auto-advances selection', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      provider.selectNumber(2);
      expect(provider.selectedNumber, 2);

      // Tap (0, 0) which is number 1
      provider.toggleMagicWandMode();
      final success = provider.tryFillCell(0, 0);
      expect(success, isTrue);
      // All cells of 1 across the artwork were filled, so auto-advance moved to 2
      expect(provider.selectedNumber, 2);
    });

    test('buyWandWithDiamonds deducts diamonds and activates wand mode', () async {
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      final initialDiamonds = settings.diamondsAvailable;
      settings.addDiamonds(100);
      final provider = ColoringProvider(storage);
      provider.loadArt(_testArt());

      final initialWands = provider.magicWandsCount;
      final success = provider.buyWandWithDiamonds(settings);
      expect(success, isTrue);
      expect(provider.magicWandsCount, initialWands + 1);
      expect(provider.isMagicWandMode, isTrue);
      expect(settings.diamondsAvailable, initialDiamonds + 100 - 40);
    });

    test('buyWandWithDiamonds with multiple count deducts correct diamonds and adds wands', () async {
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      final initialDiamonds = settings.diamondsAvailable;
      settings.addDiamonds(200);
      final provider = ColoringProvider(storage);
      provider.loadArt(_testArt());

      final initialWands = provider.magicWandsCount;
      final success = provider.buyWandWithDiamonds(settings, count: 3);
      expect(success, isTrue);
      expect(provider.magicWandsCount, initialWands + 3);
      expect(provider.isMagicWandMode, isTrue);
      expect(settings.diamondsAvailable, initialDiamonds + 200 - (40 * 3));
    });

    test('buyBombWithDiamonds deducts diamonds and activates bomb mode', () async {
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      final initialDiamonds = settings.diamondsAvailable;
      settings.addDiamonds(100);
      final provider = ColoringProvider(storage);
      provider.loadArt(_testArt());

      final initialBombs = provider.bombsCount;
      final success = provider.buyBombWithDiamonds(settings);
      expect(success, isTrue);
      expect(provider.bombsCount, initialBombs + 1);
      expect(provider.isBombMode, isTrue);
      expect(settings.diamondsAvailable, initialDiamonds + 100 - 40);
    });

    test('buyBombWithDiamonds with multiple count deducts correct diamonds and adds bombs', () async {
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      final initialDiamonds = settings.diamondsAvailable;
      settings.addDiamonds(200);
      final provider = ColoringProvider(storage);
      provider.loadArt(_testArt());

      final initialBombs = provider.bombsCount;
      final success = provider.buyBombWithDiamonds(settings, count: 4);
      expect(success, isTrue);
      expect(provider.bombsCount, initialBombs + 4);
      expect(provider.isBombMode, isTrue);
      expect(settings.diamondsAvailable, initialDiamonds + 200 - (40 * 4));
    });

    test('bomb fills all non-zero cells in a 3x3 region and decrements bomb count', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      expect(provider.bombsCount, 3);

      provider.toggleBombMode();
      expect(provider.isBombMode, isTrue);

      // Tap at the center (1, 1)
      final success = provider.tryFillCell(1, 1);
      expect(success, isTrue);
      expect(provider.isBombMode, isFalse);
      expect(provider.bombsCount, 2);

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

    test('bomb fills circular pattern with larger diameter and leaves corners unfilled', () async {
      // 15x15 art where all cells are color 1
      final grid15 = List.generate(15, (_) => List.generate(15, (_) => 1));
      final art15 = PixelArt(
        id: 'art_15',
        name: 'Art 15',
        gridWidth: 15,
        gridHeight: 15,
        grid: grid15,
        colorMap: {1: const Color(0xFFFF0000)},
      );
      final provider = await _providerWith({});
      provider.loadArt(art15);

      // Tap bomb at center (7, 7)
      provider.toggleBombMode();
      provider.tryFillCell(7, 7);

      // Center (7, 7) is filled
      expect(provider.filledGrid[7][7], 1);
      // Cardinal extremities at distance 5 are filled (diameter 11):
      expect(provider.filledGrid[2][7], 1);
      expect(provider.filledGrid[12][7], 1);
      expect(provider.filledGrid[7][2], 1);
      expect(provider.filledGrid[7][12], 1);

      // Bounding box corners at dr=5,dc=5 or dr=4,dc=4 are NOT filled in circular fill:
      expect(provider.filledGrid[2][2], 0);
      expect(provider.filledGrid[2][12], 0);
      expect(provider.filledGrid[12][2], 0);
      expect(provider.filledGrid[12][12], 0);
      expect(provider.filledGrid[3][3], 0);
      expect(provider.filledGrid[3][11], 0);

      // Total filled cells: should be 89 cells (much bigger than previous 49)
      int totalFilled = 0;
      for (var r = 0; r < 15; r++) {
        for (var c = 0; c < 15; c++) {
          if (provider.filledGrid[r][c] == 1) totalFilled++;
        }
      }
      expect(totalFilled, 89);
      expect(totalFilled > 49, isTrue);
    });

    test('bomb triggers onWaveFill with concentric distance rings', () async {
      final grid15 = List.generate(15, (_) => List.generate(15, (_) => 1));
      final art15 = PixelArt(
        id: 'art_15',
        name: 'Art 15',
        gridWidth: 15,
        gridHeight: 15,
        grid: grid15,
        colorMap: {1: const Color(0xFFFF0000)},
      );
      final provider = await _providerWith({});
      provider.loadArt(art15);

      List<List<(int, int)>>? capturedRings;
      WaveFillType? capturedType;
      int? capturedCenterR;
      int? capturedCenterC;

      provider.onWaveFill = (r, c, rings, type) {
        capturedCenterR = r;
        capturedCenterC = c;
        capturedRings = rings;
        capturedType = type;
      };

      provider.toggleBombMode();
      provider.tryFillCell(7, 7);

      expect(capturedType, WaveFillType.bomb);
      expect(capturedCenterR, 7);
      expect(capturedCenterC, 7);
      expect(capturedRings, isNotNull);
      expect(capturedRings!.length, greaterThanOrEqualTo(5));
      // Ring 0 contains the epicenter (7, 7)
      expect(capturedRings![0], [(7, 7)]);
      // All cells in ring 1 must be at Euclidean distance in [1, 2)
      for (final (r, c) in capturedRings![1]) {
        final distSq = (r - 7) * (r - 7) + (c - 7) * (c - 7);
        expect(distSq, greaterThanOrEqualTo(1));
        expect(distSq, lessThan(4));
      }
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

    test('tap on another color cell never fills or switches selection', () async {
      final provider = await _providerWith({});
      provider.loadArt(largerTestArt());
      provider.selectNumber(1);
      expect(provider.selectedNumber, 1);

      // Tap cell (0, 2) which has number 2: selection comes only from the
      // palette, so the tap must fail, leave the cell empty, keep the
      // selection, and fire the wrong-tap nudge.
      (int, int)? wrongTapAt;
      provider.onWrongTap = (row, col) => wrongTapAt = (row, col);
      final success = provider.tryFillCell(0, 2);
      expect(success, isFalse);
      expect(provider.selectedNumber, 1);
      expect(provider.filledGrid[0][2], 0);
      expect(wrongTapAt, (0, 2));
    });
  });

  group('save/load race', () {
    test('quick exit-and-reopen restores fills from an in-flight save',
        () async {
      final provider = await _providerWith({});
      final art = _testArt();
      await provider.loadArt(art);
      expect(provider.tryFillCell(0, 0), isTrue);
      expect(provider.tryFillCell(0, 1), isTrue);

      // The coloring screen fires this un-awaited from dispose; the grid
      // string is still encoding on a worker isolate when a fast re-open
      // calls loadArt. loadArt must wait for the save to land instead of
      // restoring stale storage (and later re-saving it, losing the fills).
      final inFlight = provider.saveProgress();
      await provider.loadArt(art);

      expect(provider.filledGrid[0][0], 1,
          reason: 'reopen must see the fills carried by the in-flight save');
      expect(provider.filledGrid[0][1], 1);
      await inFlight;
      provider.dispose();
    });
  });

  group('default number selection', () {
    PixelArt multiColorArt() => PixelArt(
          id: 'multi_color',
          name: 'Multi Color',
          gridWidth: 2,
          gridHeight: 2,
          grid: [
            [1, 2],
            [3, 3],
          ],
          colorMap: {
            1: const Color(0xFFFF0000),
            2: const Color(0xFF00FF00),
            3: const Color(0xFF0000FF),
          },
        );

    test('selects first number by default when fresh artwork is loaded', () async {
      final provider = await _providerWith({});
      await provider.loadArt(multiColorArt());

      expect(provider.selectedNumber, 1);
      expect(provider.highlightedNumber, 1);
      expect(provider.nextFillable, (0, 0));
    });

    test('selects first UNFILLED number by default when resuming partially completed artwork', () async {
      final provider = await _providerWith({});
      final art = multiColorArt();
      await provider.loadArt(art);

      // Complete number 1 (cell 0,0)
      provider.tryFillCell(0, 0);
      await provider.saveProgress();

      // Reload artwork
      await provider.loadArt(art);

      // Number 1 is filled, so default selection should be number 2
      expect(provider.selectedNumber, 2);
      expect(provider.highlightedNumber, 2);
      expect(provider.nextFillable, (0, 1));
    });

    test('autoMoveEnabled defaults to false and toggles properly', () async {
      final storage = LocalStorageService();
      await storage.init();
      final settings = AppSettingsProvider(storage);
      expect(settings.autoMoveEnabled, isFalse);
      settings.toggleAutoMove();
      expect(settings.autoMoveEnabled, isTrue);
      settings.toggleAutoMove();
      expect(settings.autoMoveEnabled, isFalse);
    });
  });
}
