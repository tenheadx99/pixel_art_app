import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';

class PixelGrid extends StatefulWidget {
  final ColoringProvider provider;
  final double cellSize;
  final int brushSize;
  final bool isEraseMode;
  final bool colorblindMode;
  final void Function(int row, int col) onCellTap;
  final void Function(int row, int col)? onCellLongPress;

  const PixelGrid({
    super.key,
    required this.provider,
    required this.cellSize,
    required this.brushSize,
    required this.isEraseMode,
    required this.colorblindMode,
    required this.onCellTap,
    this.onCellLongPress,
  });

  @override
  State<PixelGrid> createState() => _PixelGridState();
}

class _PixelGridState extends State<PixelGrid> {
  final _gridKey = GlobalKey();
  int? _hoverRow;
  int? _hoverCol;

  @override
  Widget build(BuildContext context) {
    final art = widget.provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    return GestureDetector(
      onTapUp: (details) {
        final pos = _gridPos(details.globalPosition, art);
        if (pos != null) widget.onCellTap(pos.$1, pos.$2);
      },
      onLongPressStart: (details) {
        if (widget.onCellLongPress == null) return;
        final pos = _gridPos(details.globalPosition, art);
        if (pos != null) widget.onCellLongPress!(pos.$1, pos.$2);
      },
      child: MouseRegion(
        onHover: (event) {
          final pos = _gridPos(event.position, art);
          setState(() {
            _hoverRow = pos?.$1;
            _hoverCol = pos?.$2;
          });
        },
        onExit: (_) => setState(() {
          _hoverRow = null;
          _hoverCol = null;
        }),
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
              size: Size(
                art.gridWidth * widget.cellSize,
                art.gridHeight * widget.cellSize,
              ),
              painter: _PixelGridPainter(
                art: art,
                filledGrid: widget.provider.filledGrid,
                filledColors: widget.provider.filledColors,
                selectedNumber: widget.provider.selectedNumber,
                showNumbers: widget.provider.showNumbers,
                highlightedNumber: widget.provider.highlightedNumber,
                nextFillable: widget.provider.nextFillable,
                cellSize: widget.cellSize,
                isEraseMode: widget.isEraseMode,
                brushSize: widget.brushSize,
                colorblindMode: widget.colorblindMode,
                hoverRow: _hoverRow,
                hoverCol: _hoverCol,
              ),
            ),
          ),
        ),
      ),
    );
  }

  (int, int)? _gridPos(Offset globalPos, dynamic art) {
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null ||
        renderBox.size.width <= 0 ||
        renderBox.size.height <= 0)
      return null;
    final localPos = renderBox.globalToLocal(globalPos);
    final col = (localPos.dx / renderBox.size.width * art.gridWidth).floor();
    final row = (localPos.dy / renderBox.size.height * art.gridHeight).floor();
    if (row >= 0 && row < art.gridHeight && col >= 0 && col < art.gridWidth)
      return (row, col);
    return null;
  }
}

class _PixelGridPainter extends CustomPainter {
  final dynamic art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;
  final int selectedNumber;
  final bool showNumbers;
  final int? highlightedNumber;
  final (int, int)? nextFillable;
  final double cellSize;
  final bool isEraseMode;
  final int brushSize;
  final bool colorblindMode;
  final int? hoverRow;
  final int? hoverCol;

  _PixelGridPainter({
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.selectedNumber,
    required this.showNumbers,
    required this.highlightedNumber,
    required this.nextFillable,
    required this.cellSize,
    required this.isEraseMode,
    required this.brushSize,
    required this.colorblindMode,
    this.hoverRow,
    this.hoverCol,
  });

  static const _patterns = [
    [10, 5],
    [12, 3],
    [8, 4, 2, 1],
    [9, 6],
    [15, 0],
    [12, 0],
  ];

  void _drawPattern(
    Canvas canvas,
    Rect rect,
    int number,
    double cw,
    double ch,
  ) {
    final idx = (number - 1) % _patterns.length;
    final pattern = _patterns[idx];
    final patPaint = Paint()..color = Colors.black.withAlpha(30);
    final rows = pattern.length;
    for (var pr = 0; pr < rows; pr++) {
      final bits = pattern[pr];
      for (var pc = 0; pc < 4; pc++) {
        if ((bits >> (3 - pc)) & 1 == 1) {
          final cx = rect.left + (pc + 0.5) * cw / 5;
          final cy = rect.top + (pr + 0.5) * ch / (rows + 1);
          canvas.drawCircle(Offset(cx, cy), min(cw, ch) / 12, patPaint);
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final cw = size.width / gridWidth;
    final ch = size.height / gridHeight;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFFF0F0F0),
    );

    final borderPaint = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final highlightPaint = Paint()..color = const Color(0x336C63FF);

    final selectedBorderPaint = Paint()
      ..color = isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF)
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
          if (colorblindMode)
            _drawPattern(canvas, rect, expectedNumber, cw, ch);

          final hl = Paint()..color = Colors.white.withAlpha(30);
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.3),
            hl,
          );
        } else if (expectedNumber == 0) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFFE8E8E8));
        } else {
          canvas.drawRect(rect, Paint()..color = Colors.white);
          if (colorblindMode)
            _drawPattern(canvas, rect, expectedNumber, cw, ch);
        }

        if (isHighlighted && !isFilled && expectedNumber > 0) {
          canvas.drawRect(rect, highlightPaint);
        }

        canvas.drawRect(rect, borderPaint);

        if (isSelected && !isFilled && expectedNumber > 0) {
          canvas.drawRect(rect.deflate(1), selectedBorderPaint);
          final glow = Paint()
            ..color =
                (isEraseMode
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF6C63FF))
                    .withAlpha(30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawRect(rect.deflate(1), glow);
        }

        if (showNumbers && !isFilled && expectedNumber > 0) {
          final textScale = min(1.0, cw / 28);
          final fontSize = (11.0 * textScale).clamp(6.0, 14.0);
          final tp = TextPainter(
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
          tp.paint(
            canvas,
            Offset(
              col * cw + (cw - tp.width) / 2,
              row * ch + (ch - tp.height) / 2,
            ),
          );
        }
      }
    }

    if (nextFillable != null && !isEraseMode) {
      final (nr, nc) = nextFillable!;
      final nRect = Rect.fromLTWH(
        nc * cw + cellGap,
        nr * ch + cellGap,
        cw - cellGap * 2,
        ch - cellGap * 2,
      );
      final pulse = Paint()
        ..color = const Color(0xFF6C63FF).withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(nRect, const Radius.circular(3)),
        pulse,
      );
      canvas.drawRect(
        nRect.deflate(2),
        Paint()..color = Colors.white.withAlpha(60),
      );
    }

    if (hoverRow != null && hoverCol != null) {
      final half = brushSize ~/ 2;
      for (var dr = -half; dr <= half; dr++) {
        for (var dc = -half; dc <= half; dc++) {
          final hr = hoverRow! + dr;
          final hc = hoverCol! + dc;
          if (hr < 0 || hr >= gridHeight || hc < 0 || hc >= gridWidth) continue;
          final hRect = Rect.fromLTWH(
            hc * cw + cellGap,
            hr * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          final cursorPaint = Paint()
            ..color =
                (isEraseMode
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF6C63FF))
                    .withAlpha(50);
          canvas.drawRect(hRect, cursorPaint);
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
