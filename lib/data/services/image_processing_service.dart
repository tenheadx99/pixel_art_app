import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class ImageProcessingService {
  Future<ui.Image> decodeImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  img.Image loadImageFromBytes(Uint8List bytes) {
    return img.decodeImage(bytes)!;
  }

  Future<img.Image> loadImageFromAsset(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    return img.decodeImage(bytes)!;
  }

  img.Image downscaleToGrid(img.Image source, int gridWidth, int gridHeight) {
    return img.copyResize(source,
        width: gridWidth, height: gridHeight, interpolation: img.Interpolation.average);
  }

  Map<int, int> quantizeColors(img.Image image, int maxColors) {
    final colorCounts = <int, int>{};
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();
        if (a < 128) continue;
        final quantized = _quantizeChannel(r) << 16 |
            _quantizeChannel(g) << 8 |
            _quantizeChannel(b);
        colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
      }
    }
    final sorted = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topColors = sorted.take(maxColors).toList();
    final colorMap = <int, int>{};
    for (var i = 0; i < topColors.length; i++) {
      colorMap[topColors[i].key] = i + 1;
    }
    return colorMap;
  }

  int _quantizeChannel(int value) {
    return (value ~/ 32) * 32;
  }

  List<List<int>> buildGridFromImage(img.Image image, Map<int, int> colorMap) {
    final grid = List.generate(image.height, (_) => List.filled(image.width, 0));
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();
        if (a < 128) {
          grid[y][x] = 0;
          continue;
        }
        final quantized = _quantizeChannel(r) << 16 |
            _quantizeChannel(g) << 8 |
            _quantizeChannel(b);
        grid[y][x] = colorMap[quantized] ?? 0;
      }
    }
    return grid;
  }

  Map<int, ui.Color> buildColorMap(Map<int, int> quantizedMap) {
    final result = <int, ui.Color>{};
    for (final entry in quantizedMap.entries) {
      final r = (entry.key >> 16) & 0xFF;
      final g = (entry.key >> 8) & 0xFF;
      final b = entry.key & 0xFF;
      result[entry.value] = ui.Color.fromARGB(255, r + 16, g + 16, b + 16);
    }
    return result;
  }
}
