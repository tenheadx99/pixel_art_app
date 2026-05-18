import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';

class ScreenshotService {
  final LocalStorageService _storageService;

  ScreenshotService(this._storageService);

  Future<Uint8List?> captureAsPng(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<String?> saveArtwork(Uint8List pngBytes, String name) async {
    final fileName = 'artwork_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = await _storageService.saveFile(fileName, pngBytes);
    return file.path;
  }
}
