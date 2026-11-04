import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/pixel_art.dart';
import '../theme/app_style.dart';

/// Floating magnifier loupe that appears above (or below) the user's touch
/// point while painting on the pixel grid. Displays an enlarged 5x5 window
/// centered around the targeted cell with numbers, reticle, and color badge.
class MagnifierLoupe extends StatelessWidget {
  final PixelArt art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;
  final int selectedNumber;
  final Offset touchPosition;
  final int targetRow;
  final int targetCol;
  final bool isDark;
  final Color primaryColor;

  const MagnifierLoupe({
    super.key,
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.selectedNumber,
    required this.touchPosition,
    required this.targetRow,
    required this.targetCol,
    required this.isDark,
    required this.primaryColor,
  });

  static const double loupeSize = 104.0;
  static const double halfSize = loupeSize / 2;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBar = MediaQuery.of(context).padding.top;

    // Determine vertical placement: prefer above the finger, flip below if too close to top
    final bool showAbove = (touchPosition.dy - 140.0) >= (statusBar + 60.0);
    final double targetY = showAbove
        ? touchPosition.dy - 130.0
        : touchPosition.dy + 35.0;

    // Clamp horizontal placement so loupe never clips against screen sides
    final double targetX = (touchPosition.dx - halfSize).clamp(
      16.0,
      math.max(16.0, screenSize.width - loupeSize - 16.0),
    );

    final bool inBounds = targetRow >= 0 &&
        targetRow < art.gridHeight &&
        targetCol >= 0 &&
        targetCol < art.gridWidth;

    final int cellNum = inBounds ? art.grid[targetRow][targetCol] : 0;
    final bool isFilled = inBounds && filledGrid[targetRow][targetCol] > 0;
    final Color cellColor = filledColors[cellNum] ??
        art.colorForNumber(cellNum) ??
        AppStyle.numberToColor(cellNum);

    return Positioned(
      left: targetX,
      top: targetY,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!showAbove) _buildIndicatorArrow(isPointingUp: true),
            // The circular loupe window
            Container(
              width: loupeSize,
              height: loupeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                border: Border.all(
                  color: cellNum == selectedNumber && !isFilled
                      ? primaryColor
                      : (isDark ? Colors.white30 : Colors.black26),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  if (cellNum == selectedNumber && !isFilled)
                    BoxShadow(
                      color: primaryColor.withAlpha(90),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(loupeSize, loupeSize),
                      painter: _LoupeGridPainter(
                        art: art,
                        filledGrid: filledGrid,
                        filledColors: filledColors,
                        selectedNumber: selectedNumber,
                        centerRow: targetRow,
                        centerCol: targetCol,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ),
                    // Center reticle
                    Center(
                      child: Container(
                        width: loupeSize / 5.0 + 2,
                        height: loupeSize / 5.0 + 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: cellNum == selectedNumber
                                ? primaryColor
                                : Colors.white,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Target Cell Metadata Capsule Badge
            if (cellNum > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF232336).withAlpha(230)
                      : Colors.white.withAlpha(240),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cellColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white38 : Colors.black26,
                          width: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '#$cellNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF222222),
                      ),
                    ),
                    if (isFilled) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 11,
                        color: Color(0xFF4CAF50),
                      ),
                    ] else if (cellNum == selectedNumber) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.brush_rounded,
                        size: 11,
                        color: primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
            if (showAbove) _buildIndicatorArrow(isPointingUp: false),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorArrow({required bool isPointingUp}) {
    return CustomPaint(
      size: const Size(14, 6),
      painter: _TrianglePointerPainter(
        color: isDark ? const Color(0xFF232336) : Colors.white,
        borderColor: isDark ? Colors.white24 : Colors.black12,
        pointingUp: isPointingUp,
      ),
    );
  }
}

class _LoupeGridPainter extends CustomPainter {
  final PixelArt art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;
  final int selectedNumber;
  final int centerRow;
  final int centerCol;
  final bool isDark;
  final Color primaryColor;

  _LoupeGridPainter({
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.selectedNumber,
    required this.centerRow,
    required this.centerCol,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int windowSpan = 2; // -2 to +2 = 5x5 cells
    final double cellSide = size.width / 5.0;

    final bgPaint = Paint()..color = isDark ? const Color(0xFF14141E) : const Color(0xFFF0F0F4);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cellFillPaint = Paint()..style = PaintingStyle.fill;
    final selectHighlightPaint = Paint()
      ..color = primaryColor.withAlpha(45)
      ..style = PaintingStyle.fill;

    for (int dr = -windowSpan; dr <= windowSpan; dr++) {
      for (int dc = -windowSpan; dc <= windowSpan; dc++) {
        final r = centerRow + dr;
        final c = centerCol + dc;
        final cellRect = Rect.fromLTWH(
          (dc + windowSpan) * cellSide,
          (dr + windowSpan) * cellSide,
          cellSide,
          cellSide,
        );

        if (r < 0 || r >= art.gridHeight || c < 0 || c >= art.gridWidth) {
          // Out of grid bounds
          continue;
        }

        final expected = art.grid[r][c];
        if (expected == 0) continue;

        final isFilled = filledGrid[r][c] > 0;
        if (isFilled) {
          final color = filledColors[expected] ??
              art.colorForNumber(expected) ??
              AppStyle.numberToColor(expected);
          cellFillPaint.color = color;
          canvas.drawRect(cellRect, cellFillPaint);
        } else {
          // Unfilled
          if (expected == selectedNumber) {
            canvas.drawRect(cellRect, selectHighlightPaint);
          }

          // Draw number text
          final textColor = (expected == selectedNumber)
              ? primaryColor
              : (isDark ? Colors.white70 : const Color(0xFF444444));

          final tp = TextPainter(
            text: TextSpan(
              text: '$expected',
              style: TextStyle(
                color: textColor,
                fontSize: cellSide * 0.44,
                fontWeight: (expected == selectedNumber) ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          tp.paint(
            canvas,
            Offset(
              cellRect.left + (cellSide - tp.width) / 2,
              cellRect.top + (cellSide - tp.height) / 2,
            ),
          );
        }

        canvas.drawRect(cellRect, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoupeGridPainter old) {
    return old.centerRow != centerRow ||
        old.centerCol != centerCol ||
        old.selectedNumber != selectedNumber ||
        old.isDark != isDark;
  }
}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool pointingUp;

  _TrianglePointerPainter({
    required this.color,
    required this.borderColor,
    required this.pointingUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointingUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter old) =>
      old.color != color || old.pointingUp != pointingUp;
}

