import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_art_app/data/models/pixel_art.dart';

/// Renders the coloring history as an animated GIF for sharing.
class TimelapseService {
  /// Returns encoded GIF bytes, or null if there is nothing to render.
  /// Encoding runs in a background isolate.
  static Future<Uint8List?> renderGif({
    required PixelArt art,
    required List<(int, int)> actions,
    int cellPx = 12,
    int frameCount = 30,
  }) async {
    if (actions.isEmpty) return null;
    // Flatten to isolate-safe primitives: dart:ui Colors don't cross isolates.
    final job = _GifJob(
      gridWidth: art.gridWidth,
      gridHeight: art.gridHeight,
      grid: art.grid,
      colorArgb: art.colorMap.map((k, v) => MapEntry(k, v.toARGB32())),
      actions: actions.map((a) => [a.$1, a.$2]).toList(),
      cellPx: cellPx,
      frameCount: frameCount,
    );
    return compute(_encodeGif, job);
  }
}

class _GifJob {
  final int gridWidth;
  final int gridHeight;
  final List<List<int>> grid;
  final Map<int, int> colorArgb;
  final List<List<int>> actions;
  final int cellPx;
  final int frameCount;

  const _GifJob({
    required this.gridWidth,
    required this.gridHeight,
    required this.grid,
    required this.colorArgb,
    required this.actions,
    required this.cellPx,
    required this.frameCount,
  });
}

Uint8List? _encodeGif(_GifJob job) {
  final width = job.gridWidth * job.cellPx;
  final height = job.gridHeight * job.cellPx;
  final encoder = img.GifEncoder(repeat: 0);

  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgb8(245, 245, 245));

  void paintCell(int row, int col) {
    final number = job.grid[row][col];
    final argb = job.colorArgb[number];
    if (argb == null) return;
    img.fillRect(
      canvas,
      x1: col * job.cellPx,
      y1: row * job.cellPx,
      x2: (col + 1) * job.cellPx - 1,
      y2: (row + 1) * job.cellPx - 1,
      color: img.ColorRgb8(
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
      ),
    );
  }

  final perFrame = (job.actions.length / job.frameCount).ceil().clamp(1, 1 << 30);
  var painted = 0;
  while (painted < job.actions.length) {
    final end = (painted + perFrame).clamp(0, job.actions.length);
    for (; painted < end; painted++) {
      paintCell(job.actions[painted][0], job.actions[painted][1]);
    }
    encoder.addFrame(img.Image.from(canvas), duration: 8);
  }
  // Hold the finished artwork before looping.
  encoder.addFrame(img.Image.from(canvas), duration: 200);
  return encoder.finish();
}
