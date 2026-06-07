import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify all pixel art assets listed in manifest.json are valid', () {
    final manifestFile = File('assets/pixel_art/manifest.json');
    expect(manifestFile.existsSync(), isTrue, reason: 'manifest.json should exist');

    final manifestContent = manifestFile.readAsStringSync();
    final manifestList = jsonDecode(manifestContent) as List<dynamic>;
    expect(manifestList, isNotEmpty, reason: 'manifest.json should not be empty');

    for (final assetPath in manifestList) {
      final pathStr = assetPath as String;
      final file = File(pathStr);
      expect(file.existsSync(), isTrue, reason: 'Asset file $pathStr should exist');

      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Verify core properties
      expect(data['id'], isNotNull, reason: '$pathStr: id should be defined');
      expect(data['name'], isNotNull, reason: '$pathStr: name should be defined');
      expect(data['gridWidth'], isA<int>(), reason: '$pathStr: gridWidth should be an int');
      expect(data['gridHeight'], isA<int>(), reason: '$pathStr: gridHeight should be an int');
      expect(data['grid'], isA<String>(), reason: '$pathStr: grid should be a String');
      expect(data['colorMap'], isA<Map<String, dynamic>>(), reason: '$pathStr: colorMap should be a Map');
      expect(data['category'], isA<String>(), reason: '$pathStr: category should be a String');
      expect(data['difficulty'], isA<int>(), reason: '$pathStr: difficulty should be an int');
      expect(data['isPremium'], isA<bool>(), reason: '$pathStr: isPremium should be a bool');

      final width = data['gridWidth'] as int;
      final height = data['gridHeight'] as int;
      expect(width, greaterThan(0));
      expect(height, greaterThan(0));

      // Verify grid structure
      final gridStr = data['grid'] as String;
      final rows = gridStr.split(';');
      expect(rows.length, equals(height), reason: '$pathStr: Number of grid rows should match gridHeight');

      final colorMap = data['colorMap'] as Map<String, dynamic>;
      final colorKeys = colorMap.keys.map(int.parse).toSet();

      for (int i = 0; i < rows.length; i++) {
        final cols = rows[i].split(',');
        expect(cols.length, equals(width), reason: '$pathStr: Row $i length should match gridWidth');
        
        for (int j = 0; j < cols.length; j++) {
          final cellValue = int.tryParse(cols[j]);
          expect(cellValue, isNotNull, reason: '$pathStr: Cell at row $i, col $j is not a valid integer');
          
          if (cellValue != 0) {
            expect(colorKeys.contains(cellValue), isTrue, 
                reason: '$pathStr: Cell color index $cellValue at row $i, col $j is not defined in colorMap');
          }
        }
      }

      // Verify colors in colorMap are integers (color hex values)
      for (final entry in colorMap.entries) {
        expect(int.tryParse(entry.key), isNotNull, reason: '$pathStr: colorMap key ${entry.key} must be parseable as an integer');
        expect(entry.value, isA<num>(), reason: '$pathStr: colorMap value ${entry.value} must be a number');
      }
    }
  });
}
