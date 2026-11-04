import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/models/pixel_art.dart';
import '../data/services/pixel_converter_service.dart';

class CameraProvider extends ChangeNotifier {
  final PixelConverterService _converter = PixelConverterService();

  Uint8List? _selectedImage;
  PixelArt? _convertedArt;
  int _gridSize = 32;
  int _maxColors = 12;
  String _filter = 'normal';
  bool _dither = false;
  bool _isConverting = false;

  Uint8List? get selectedImage => _selectedImage;
  PixelArt? get convertedArt => _convertedArt;
  int get gridSize => _gridSize;
  int get maxColors => _maxColors;
  String get filter => _filter;
  bool get dither => _dither;
  bool get isConverting => _isConverting;

  void setImage(Uint8List bytes) {
    _selectedImage = bytes;
    _convertedArt = null;
    notifyListeners();
  }

  void setGridSize(int size) {
    _gridSize = size;
    notifyListeners();
  }

  void setMaxColors(int colors) {
    _maxColors = colors;
    notifyListeners();
  }

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  void toggleDither() {
    _dither = !_dither;
    notifyListeners();
  }

  /// Generates a pristine blank pixel art canvas for custom creations.
  PixelArt createBlankCanvas({
    required String name,
    int size = 24,
    String paletteStyle = 'retro',
  }) {
    final Map<int, Color> colors = switch (paletteStyle) {
      'pastel' => {
          1: const Color(0xFFFFB3BA),
          2: const Color(0xFFFFDFBA),
          3: const Color(0xFFFFFFBA),
          4: const Color(0xFFBAFFC9),
          5: const Color(0xFFBAE1FF),
          6: const Color(0xFFE8BAFF),
          7: const Color(0xFFFFFFFF),
          8: const Color(0xFF4A4A4A),
        },
      'vibrant' => {
          1: const Color(0xFFFF1744),
          2: const Color(0xFFFF9100),
          3: const Color(0xFFFFEA00),
          4: const Color(0xFF00E676),
          5: const Color(0xFF00B0FF),
          6: const Color(0xFFD500F9),
          7: const Color(0xFF212121),
          8: const Color(0xFFFFFFFF),
        },
      _ => {
          1: const Color(0xFF000000),
          2: const Color(0xFFFFFFFF),
          3: const Color(0xFF880000),
          4: const Color(0xFFAAFFEE),
          5: const Color(0xFFCC44CC),
          6: const Color(0xFF00CC55),
          7: const Color(0xFF0000AA),
          8: const Color(0xFFEEEE77),
          9: const Color(0xFFDD8855),
          10: const Color(0xFF664400),
          11: const Color(0xFFFF7777),
          12: const Color(0xFF333333),
        },
    };

    final grid = List.generate(size, (_) => List.filled(size, 0));

    return PixelArt(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      gridWidth: size,
      gridHeight: size,
      grid: grid,
      colorMap: colors,
      category: 'Custom',
      difficulty: size ~/ 8,
      isPremium: false,
    );
  }

  Future<void> convertImage(String name) async {
    if (_selectedImage == null) return;
    _isConverting = true;
    notifyListeners();

    try {
      _convertedArt = await _converter.convertPhotoToPixelArt(
        imageBytes: _selectedImage!,
        name: name,
        gridWidth: _gridSize,
        gridHeight: _gridSize,
        maxColors: _maxColors,
        filter: _filter,
        dither: _dither,
      );
    } catch (e, st) {
      developer.log('Photo-to-pixel conversion failed',
          name: 'CameraProvider', error: e, stackTrace: st);
    }

    _isConverting = false;
    notifyListeners();
  }

  void clear() {
    _selectedImage = null;
    _convertedArt = null;
    _isConverting = false;
    notifyListeners();
  }
}
