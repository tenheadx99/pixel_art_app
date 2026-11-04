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
    return img.copyResize(
      source,
      width: gridWidth,
      height: gridHeight,
      interpolation: img.Interpolation.average,
    );
  }

  /// Applies optional photographic style pre-processing before pixel conversion.
  img.Image applyFilter(img.Image image, String filter) {
    switch (filter.toLowerCase()) {
      case 'vibrant':
        return img.adjustColor(image, saturation: 1.45, contrast: 1.2);
      case 'sepia':
        return img.sepia(image);
      case 'monochrome':
        return img.grayscale(image);
      case 'normal':
      default:
        return image;
    }
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
        final quantized =
            _quantizeChannel(r) << 16 |
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

  List<List<int>> buildGridFromImage(
    img.Image image,
    Map<int, int> colorMap, {
    bool dither = false,
  }) {
    final w = image.width;
    final h = image.height;
    final grid = List.generate(
      h,
      (_) => List.filled(w, 0),
    );

    // If dithering is requested, we keep error buffers across rows
    final errR = List.generate(h, (_) => List<double>.filled(w, 0.0));
    final errG = List.generate(h, (_) => List<double>.filled(w, 0.0));
    final errB = List.generate(h, (_) => List<double>.filled(w, 0.0));

    final nearestCache = <int, int>{};

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a.toInt();
        if (a < 128) {
          grid[y][x] = 0;
          continue;
        }

        double r = pixel.r.toDouble();
        double g = pixel.g.toDouble();
        double b = pixel.b.toDouble();

        if (dither) {
          r = (r + errR[y][x]).clamp(0.0, 255.0);
          g = (g + errG[y][x]).clamp(0.0, 255.0);
          b = (b + errB[y][x]).clamp(0.0, 255.0);
        }

        final quantized =
            _quantizeChannel(r.round()) << 16 |
            _quantizeChannel(g.round()) << 8 |
            _quantizeChannel(b.round());

        final colorNum = colorMap[quantized] ??
            nearestCache.putIfAbsent(
                quantized, () => _nearestColorNumber(colorMap, quantized));

        grid[y][x] = colorNum;

        if (dither) {
          // Find RGB of the chosen color in colorMap
          int chosenKey = quantized;
          for (final entry in colorMap.entries) {
            if (entry.value == colorNum) {
              chosenKey = entry.key;
              break;
            }
          }
          final matchR = ((chosenKey >> 16) & 0xFF).toDouble();
          final matchG = ((chosenKey >> 8) & 0xFF).toDouble();
          final matchB = (chosenKey & 0xFF).toDouble();

          final diffR = r - matchR;
          final diffG = g - matchG;
          final diffB = b - matchB;

          // Floyd-Steinberg error distribution:
          // x+1, y: 7/16
          // x-1, y+1: 3/16
          // x,   y+1: 5/16
          // x+1, y+1: 1/16
          if (x + 1 < w) {
            errR[y][x + 1] += diffR * (7.0 / 16.0);
            errG[y][x + 1] += diffG * (7.0 / 16.0);
            errB[y][x + 1] += diffB * (7.0 / 16.0);
          }
          if (y + 1 < h) {
            if (x - 1 >= 0) {
              errR[y + 1][x - 1] += diffR * (3.0 / 16.0);
              errG[y + 1][x - 1] += diffG * (3.0 / 16.0);
              errB[y + 1][x - 1] += diffB * (3.0 / 16.0);
            }
            errR[y + 1][x] += diffR * (5.0 / 16.0);
            errG[y + 1][x] += diffG * (5.0 / 16.0);
            errB[y + 1][x] += diffB * (5.0 / 16.0);
            if (x + 1 < w) {
              errR[y + 1][x + 1] += diffR * (1.0 / 16.0);
              errG[y + 1][x + 1] += diffG * (1.0 / 16.0);
              errB[y + 1][x + 1] += diffB * (1.0 / 16.0);
            }
          }
        }
      }
    }
    return grid;
  }

  int _nearestColorNumber(Map<int, int> colorMap, int quantized) {
    final r = (quantized >> 16) & 0xFF;
    final g = (quantized >> 8) & 0xFF;
    final b = quantized & 0xFF;
    var best = 0;
    var bestDist = 1 << 30;
    for (final entry in colorMap.entries) {
      final dr = r - ((entry.key >> 16) & 0xFF);
      final dg = g - ((entry.key >> 8) & 0xFF);
      final db = b - (entry.key & 0xFF);
      final dist = dr * dr + dg * dg + db * db;
      if (dist < bestDist) {
        bestDist = dist;
        best = entry.value;
      }
    }
    return best;
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
