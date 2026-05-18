import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';

class PixelGrid extends StatefulWidget {
  final ColoringProvider provider;
  final double cellSize;
  final void Function(int row, int col) onCellTap;

  const PixelGrid({
    super.key,
    required this.provider,
    required this.cellSize,
    required this.onCellTap,
  });

  @override
  State<PixelGrid> createState() => _PixelGridState();
}

class _PixelGridState extends State<PixelGrid> {
  final _gridKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final art = widget.provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    return GestureDetector(
      onTapUp: (details) {
        final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || renderBox.size.width <= 0 || renderBox.size.height <= 0) return;
        final localPos = renderBox.globalToLocal(details.globalPosition);
        final col = (localPos.dx / renderBox.size.width * art.gridWidth).floor();
        final row = (localPos.dy / renderBox.size.height * art.gridHeight).floor();
        if (row >= 0 && row < art.gridHeight && col >= 0 && col < art.gridWidth) {
          widget.onCellTap(row, col);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            key: _gridKey,
            size: Size(art.gridWidth * widget.cellSize, art.gridHeight * widget.cellSize),
            painter: _PixelGridPainter(
              art: art,
              filledGrid: widget.provider.filledGrid,
              filledColors: widget.provider.filledColors,
              selectedNumber: widget.provider.selectedNumber,
              showNumbers: widget.provider.showNumbers,
              highlightedNumber: widget.provider.highlightedNumber,
              cellSize: widget.cellSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  final dynamic art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;
  final int selectedNumber;
  final bool showNumbers;
  final int? highlightedNumber;
  final double cellSize;

  _PixelGridPainter({
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.selectedNumber,
    required this.showNumbers,
    required this.highlightedNumber,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;

    final cw = size.width / gridWidth;
    final ch = size.height / gridHeight;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFF0F0F0),
    );

    final borderPaint = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final highlightPaint = Paint()
      ..color = const Color(0x336C63FF);

    final selectedBorderPaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final cellGap = 0.5;

    for (var row = 0; row < gridHeight; row++) {
      for (var col = 0; col < gridWidth; col++) {
        final expectedNumber = art.grid[row][col] as int;
        final isFilled = filledGrid[row][col] > 0;
        final isSelected = expectedNumber == selectedNumber;
        final isHighlighted =
            highlightedNumber != null && expectedNumber == highlightedNumber;

        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );

        if (isFilled) {
          final fillColor = filledColors[expectedNumber] ?? Colors.grey;
          canvas.drawRect(rect, Paint()..color = fillColor);

          final highlight = Paint()
            ..color = Colors.white.withAlpha(30);
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.3),
            highlight,
          );
        } else if (expectedNumber == 0) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFE8E8E8));
        } else {
          canvas.drawRect(rect, Paint()..color = Colors.white);
        }

        if (isHighlighted && !isFilled && expectedNumber > 0) {
          canvas.drawRect(rect, highlightPaint);
        }

        canvas.drawRect(rect, borderPaint);

        if (isSelected && !isFilled && expectedNumber > 0) {
          canvas.drawRect(
            rect.deflate(1),
            selectedBorderPaint,
          );

          final glowPaint = Paint()
            ..color = const Color(0xFF6C63FF).withAlpha(30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawRect(rect.deflate(1), glowPaint);
        }

        if (showNumbers && !isFilled && expectedNumber > 0) {
          final textScale = min(1.0, cw / 28);
          final fontSize = (11.0 * textScale).clamp(6.0, 14.0);

          final textPainter = TextPainter(
            text: TextSpan(
              text: '$expectedNumber',
              style: TextStyle(
                color: const Color(0xFF999999),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            Offset(
              col * cw + (cw - textPainter.width) / 2,
              row * ch + (ch - textPainter.height) / 2,
            ),
          );
        }
      }
    }

    final edgePaint = Paint()
      ..color = const Color(0x44000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) => true;
}
