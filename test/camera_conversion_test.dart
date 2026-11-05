import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_art_app/data/services/pixel_converter_service.dart';

void main() {
  test('convertPhotoToPixelArt converts synthetic image with filters and dither', () async {
    final service = PixelConverterService();

    // Create a 64x64 synthetic image with gradients
    final image = img.Image(width: 64, height: 64);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        image.setPixelRgba(x, y, x * 4, y * 4, 128, 255);
      }
    }
    final pngBytes = Uint8List.fromList(img.encodePng(image));

    final art = await service.convertPhotoToPixelArt(
      imageBytes: pngBytes,
      name: 'Test Art',
      gridWidth: 32,
      gridHeight: 32,
      maxColors: 12,
      filter: 'vibrant',
      dither: true,
    );

    expect(art.gridWidth, 32);
    expect(art.gridHeight, 32);
    expect(art.colorMap.isNotEmpty, true);
    print('Converted art colors: ${art.colorMap.length}, fillable: ${art.fillableCells}');
  });

  test('convertPhotoToPixelArt handles bright white pixels without Color.fromARGB overflow', () async {
    final service = PixelConverterService();

    final image = img.Image(width: 32, height: 32);
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
        image.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
    final pngBytes = Uint8List.fromList(img.encodePng(image));

    final art = await service.convertPhotoToPixelArt(
      imageBytes: pngBytes,
      name: 'Bright Art',
      gridWidth: 16,
      gridHeight: 16,
      maxColors: 8,
      filter: 'sepia',
      dither: false,
    );

    expect(art.gridWidth, 16);
    expect(art.colorMap.isNotEmpty, true);
  });
}
