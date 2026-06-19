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
  });
}
