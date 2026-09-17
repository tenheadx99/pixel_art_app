import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';

/// Static preview of an artwork, used by catalog cards, the daily banner and
/// the split-artwork part picker.
///
/// One drawRawPoints call per color instead of a drawRect per cell —
/// a 128x128 preview is otherwise ~16k draw ops per card.
class ArtPreviewPainter extends CustomPainter {
  final PixelArt art;
  final bool isCompleted;

  /// Optional per-cell fill state (same dims as [art.grid]): true cells render
  /// full color, false cells dimmed. When null, [isCompleted] applies to the
  /// whole artwork. Lets the part picker show real coloring progress.
  final List<List<bool>>? filledMask;

  ArtPreviewPainter({
    required this.art,
    required this.isCompleted,
    this.filledMask,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / art.gridWidth;
    final ch = size.height / art.gridHeight;

    final batches = <int, List<double>>{};
    for (var r = 0; r < art.gridHeight; r++) {
      for (var c = 0; c < art.gridWidth; c++) {
        final val = art.grid[r][c];
        if (val <= 0) continue;
        final color = art.colorForNumber(val) ?? Colors.transparent;
        final full = filledMask?[r][c] ?? isCompleted;
        final key = (full ? color : color.withAlpha(90)).toARGB32();
        batches.putIfAbsent(key, () => <double>[])
          ..add(c * cw + cw / 2)
          ..add(r * ch + ch / 2);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = max(cw, ch);
    for (final entry in batches.entries) {
      paint.color = Color(entry.key);
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(entry.value),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArtPreviewPainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.isCompleted != isCompleted ||
      oldDelegate.filledMask != filledMask;
}

/// Renders [art] fully colored to a PNG offscreen (no widget tree needed).
/// Used for the merged export of a completed split artwork, where no single
/// coloring canvas ever held the whole grid.
Future<Uint8List?> renderArtPng(PixelArt art, {int cellPx = 4}) async {
  final size = Size(
    (art.gridWidth * cellPx).toDouble(),
    (art.gridHeight * cellPx).toDouble(),
  );
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  ArtPreviewPainter(art: art, isCompleted: true).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}
