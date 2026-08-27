import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_catalog_service.dart';
import 'package:pixel_art_app/data/services/progress_migration_strategy.dart';
import 'package:pixel_art_app/data/services/pixel_converter_service.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/data/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteCatalogService & Dynamic Content Tests', () {
    test('ProgressMigrationStrategy validates and parses valid dynamic grids', () {
      final art = PixelArt(
        id: 'test_art',
        name: 'Test',
        gridWidth: 2,
        gridHeight: 2,
        grid: [
          [1, 2],
          [2, 1],
        ],
        colorMap: {1: const Color(0xFFFF0000), 2: const Color(0xFF00FF00)},
      );

      const validSaveString = '1,2;0,1';
      expect(ProgressMigrationStrategy.isGridCompatible(validSaveString, art), isTrue);

      final parsed = ProgressMigrationStrategy.parseAndValidateGrid(
        rawGridString: validSaveString,
        art: art,
      );
      expect(parsed[0][0], 1);
      expect(parsed[0][1], 2);
      expect(parsed[1][0], 0);
      expect(parsed[1][1], 1);

      const invalidSaveString = '1,2,3;0,1';
      expect(ProgressMigrationStrategy.isGridCompatible(invalidSaveString, art), isFalse);

      final fallback = ProgressMigrationStrategy.parseAndValidateGrid(
        rawGridString: invalidSaveString,
        art: art,
      );
      expect(fallback[0][0], 0); // Reset safely to 0
    });

    test('GalleryProvider blends dynamic artworks seamlessly into catalog', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.init();
      final db = DatabaseService();

      final provider = GalleryProvider(storage, db);
      final baseArt = PixelArt(
        id: 'base_1',
        name: 'Base Art',
        gridWidth: 2,
        gridHeight: 2,
        grid: [[1, 1], [1, 1]],
        colorMap: {1: const Color(0xFFFF0000)},
      );

      await provider.loadCatalog([baseArt]);
      expect(provider.catalog.length, 1);

      final dynamicArt = PixelArt(
        id: 'dynamic_101',
        name: 'Remote Dynamic Art',
        gridWidth: 2,
        gridHeight: 2,
        grid: [[2, 2], [2, 2]],
        colorMap: {2: const Color(0xFF0000FF)},
      );

      provider.addDynamicArtworks([dynamicArt]);
      expect(provider.catalog.length, 2);
      expect(provider.catalog.any((a) => a.id == 'dynamic_101'), isTrue);
    });

    test('PixelConverterService exports dynamic artwork to .pixely JSON format', () {
      final service = PixelConverterService();
      final art = PixelArt(
        id: 'export_test',
        name: 'Exported Art',
        gridWidth: 2,
        gridHeight: 2,
        grid: [[1, 1], [1, 1]],
        colorMap: {1: const Color(0xFFFF0000)},
      );

      final exportedString = service.exportToPixelyFormat(art);
      expect(exportedString.contains('"exportVersion": 1'), isTrue);
      expect(exportedString.contains('"id": "export_test"'), isTrue);

      final decoded = jsonDecode(exportedString) as Map<String, dynamic>;
      final reloaded = PixelArt.fromJson(decoded);
      expect(reloaded.id, 'export_test');
    });
  });
}
