import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/image_processing_service.dart';

class PixelConverterService {
  final ImageProcessingService _imageProcessing = ImageProcessingService();

  Future<PixelArt> convertPhotoToPixelArt({
    required Uint8List imageBytes,
    required String name,
    int gridWidth = 32,
    int gridHeight = 32,
    int maxColors = 16,
  }) async {
    final imgSrc = _imageProcessing.loadImageFromBytes(imageBytes);
    final resized = _imageProcessing.downscaleToGrid(imgSrc, gridWidth, gridHeight);
    final quantizedMap = _imageProcessing.quantizeColors(resized, maxColors);
    final grid = _imageProcessing.buildGridFromImage(resized, quantizedMap);
    final colorMap = _imageProcessing.buildColorMap(quantizedMap);

    colorMap.remove(0);

    return PixelArt(
      id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      grid: grid,
      colorMap: colorMap,
      category: 'Photo',
      difficulty: (gridWidth ~/ 8),
      isPremium: false,
    );
  }

  List<PixelArt> loadPreMadePixelfromBundle(String bundleData) {
    final arts = <PixelArt>[];
    final lines = bundleData.trim().split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        arts.add(PixelArt.fromJson(json));
      } catch (_) {}
    }
    return arts;
  }

  Future<List<PixelArt>> loadPreMadeAssets() async {
    final arts = <PixelArt>[];
    try {
      final manifestJson = await rootBundle.loadString('assets/pixel_art/manifest.json');
      final manifest = jsonDecode(manifestJson) as List<dynamic>;
      for (final entry in manifest) {
        final path = entry as String;
        final content = await rootBundle.loadString(path);
        final json = jsonDecode(content) as Map<String, dynamic>;
        arts.add(PixelArt.fromJson(json));
      }
    } catch (e) {
      debugPrint('loadPreMadeAssets error: $e');
    }
    return arts;
  }
}
