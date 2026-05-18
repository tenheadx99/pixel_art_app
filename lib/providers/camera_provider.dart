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
  bool _isConverting = false;

  Uint8List? get selectedImage => _selectedImage;
  PixelArt? get convertedArt => _convertedArt;
  int get gridSize => _gridSize;
  int get maxColors => _maxColors;
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
      );
    } catch (e) {
      debugPrint('Conversion failed: $e');
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
