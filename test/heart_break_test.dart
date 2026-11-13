import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Path buildMaterialHeartHalf({
  required Size size,
  required bool isLeft,
  required List<Offset> zigzagPoints,
}) {
  final sx = size.width / 24.0;
  final sy = size.height / 24.0;
  final path = Path();

  if (isLeft) {
    // Top cleft
    path.moveTo(zigzagPoints.first.dx, zigzagPoints.first.dy);

    // Curve 1: Cleft to Top-Left peak
    path.cubicTo(
      10.91 * sx, 3.81 * sy,
      9.24 * sx, 3.0 * sy,
      7.5 * sx, 3.0 * sy,
    );

    // Curve 2: Top-Left peak to Outer-Left edge
    path.cubicTo(
      4.42 * sx, 3.0 * sy,
      2.0 * sx, 5.42 * sy,
      2.0 * sx, 8.5 * sy,
    );

    // Curve 3: Outer-Left edge to Lower taper
    path.cubicTo(
      2.0 * sx, 12.28 * sy,
      5.4 * sx, 15.36 * sy,
      10.55 * sx, 20.03 * sy,
    );

    // Bottom tip
    path.lineTo(zigzagPoints.last.dx, zigzagPoints.last.dy);

    // Zigzag back up
    for (int i = zigzagPoints.length - 2; i >= 0; i--) {
      path.lineTo(zigzagPoints[i].dx, zigzagPoints[i].dy);
    }
    path.close();
  } else {
    // Top cleft
    path.moveTo(zigzagPoints.first.dx, zigzagPoints.first.dy);

    // Zigzag down
    for (int i = 1; i < zigzagPoints.length; i++) {
      path.lineTo(zigzagPoints[i].dx, zigzagPoints[i].dy);
    }

    // Lower taper
    path.lineTo(13.45 * sx, 20.03 * sy);

    // Curve 1: Lower taper to Outer-Right edge
    path.cubicTo(
      18.6 * sx, 15.36 * sy,
      22.0 * sx, 12.28 * sy,
      22.0 * sx, 8.5 * sy,
    );

    // Curve 2: Outer-Right edge to Top-Right peak
    path.cubicTo(
      22.0 * sx, 5.42 * sy,
      19.58 * sx, 3.0 * sy,
      16.5 * sx, 3.0 * sy,
    );

    // Curve 3: Top-Right peak to Top cleft
    path.cubicTo(
      14.76 * sx, 3.0 * sy,
      13.09 * sx, 3.81 * sy,
      zigzagPoints.first.dx, zigzagPoints.first.dy,
    );
    path.close();
  }

  return path;
}

void main() {
  test('Material heart halves create perfect heart outline and close cleanly', () {
    const size = Size(36, 36);
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;

    final zigzagPoints = [
      Offset(12.0 * sx, 5.09 * sy),
      Offset(10.3 * sx, 8.2 * sy),
      Offset(13.8 * sx, 11.5 * sy),
      Offset(10.5 * sx, 14.8 * sy),
      Offset(13.4 * sx, 17.8 * sy),
      Offset(12.0 * sx, 21.35 * sy),
    ];

    final leftPath = buildMaterialHeartHalf(size: size, isLeft: true, zigzagPoints: zigzagPoints);
    final rightPath = buildMaterialHeartHalf(size: size, isLeft: false, zigzagPoints: zigzagPoints);

    expect(leftPath.getBounds().isEmpty, isFalse);
    expect(rightPath.getBounds().isEmpty, isFalse);

    // Combined bounds should be approx [2*sx .. 22*sx] in X and [3*sy .. 21.35*sy] in Y
    final leftBounds = leftPath.getBounds();
    final rightBounds = rightPath.getBounds();

    expect(leftBounds.left, closeTo(2.0 * sx, 0.5));
    expect(rightBounds.right, closeTo(22.0 * sx, 0.5));
    expect(leftBounds.top, closeTo(3.0 * sy, 0.5));
    expect(rightBounds.top, closeTo(3.0 * sy, 0.5));
    expect(leftBounds.bottom, closeTo(21.35 * sy, 0.5));
    expect(rightBounds.bottom, closeTo(21.35 * sy, 0.5));
  });
}
