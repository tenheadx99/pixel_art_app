import 'dart:math';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';

class PixelGrid extends StatefulWidget {
  final ColoringProvider provider;
  final double cellSize;
  final int brushSize;
  final bool isEraseMode;
  final bool colorblindMode;

  /// Completion fade (0.0 = working grid, 1.0 = clean picture). Wired as a
  /// listenable so the canvas repaints without rebuilding the widget tree.
  final Animation<double>? gridFade;

  /// The InteractiveViewer's transformation. Drives level-of-detail (numbers
  /// hide and a grayscale preview appears when zoomed out) and, as a
  /// listenable, repaints the canvas per zoom frame without any setState.
  final ValueListenable<Matrix4>? transform;
  final void Function(int row, int col) onCellTap;
  final void Function(int row, int col)? onCellLongPress;
  final VoidCallback? onCellDragStart;
  final void Function(int row, int col)? onCellDrag;
  final VoidCallback? onCellDragEnd;
  final VoidCallback? onCellDragCancel;

  const PixelGrid({
    super.key,
    required this.provider,
    required this.cellSize,
    required this.brushSize,
    required this.isEraseMode,
    required this.colorblindMode,
    this.gridFade,
    this.transform,
    required this.onCellTap,
    this.onCellLongPress,
    this.onCellDragStart,
    this.onCellDrag,
    this.onCellDragEnd,
    this.onCellDragCancel,
  });

  @override
  State<PixelGrid> createState() => _PixelGridState();
}

class _PixelGridState extends State<PixelGrid> {
  final _gridKey = GlobalKey();
  int? _hoverRow;
  int? _hoverCol;
  int _activePointers = 0;
  bool _stroking = false;
  Offset? _downPosition;

  // Drag-to-paint listens to raw pointer events instead of a pan gesture so
  // it never enters the gesture arena: a pan recognizer here would claim the
  // first finger and starve InteractiveViewer's two-finger pinch-zoom.
  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1) {
      _downPosition = event.position;
    } else {
      // Second finger: this is a pinch, not a stroke. Revert any paint.
      _downPosition = null;
      if (_stroking) {
        _stroking = false;
        widget.onCellDragCancel?.call();
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final art = widget.provider.currentArt;
    if (art == null || widget.onCellDrag == null) return;
    if (_activePointers != 1) return;
    if (!_stroking) {
      final down = _downPosition;
      if (down == null || (event.position - down).distance < kTouchSlop) {
        return;
      }
      _stroking = true;
      widget.onCellDragStart?.call();
    }
    final pos = _gridPos(event.position, art);
    if (pos != null) widget.onCellDrag!(pos.$1, pos.$2);
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers = max(0, _activePointers - 1);
    _downPosition = null;
    if (_stroking && _activePointers == 0) {
      _stroking = false;
      widget.onCellDragEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: GestureDetector(
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
                  gridFade: widget.gridFade,
                  transform: widget.transform,
                  hoverRow: _hoverRow,
                  hoverCol: _hoverCol,
                ),
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
        renderBox.size.height <= 0) {
      return null;
    }
    final localPos = renderBox.globalToLocal(globalPos);
    final col = (localPos.dx / renderBox.size.width * art.gridWidth).floor();
    final row = (localPos.dy / renderBox.size.height * art.gridHeight).floor();
    if (row >= 0 && row < art.gridHeight && col >= 0 && col < art.gridWidth) {
      return (row, col);
    }
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
  final Animation<double>? gridFade;
  final ValueListenable<Matrix4>? transform;
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
    this.gridFade,
    this.transform,
    this.hoverRow,
    this.hoverCol,
  }) : super(repaint: Listenable.merge([gridFade, transform]));

  /// Laid-out number labels, cached across frames and painter instances.
  /// Keyed by number, font size, and the quantized LOD fade step — without
  /// this, every visible cell allocated and laid out a TextPainter per frame.
  static final Map<int, TextPainter> _textCache = {};

  static TextPainter _numberPainter(int number, double fontSize, int alphaStep) {
    final key = number * 10000 + (fontSize * 10).round() * 10 + alphaStep;
    return _textCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            color: const Color(0xFF999999)
                .withAlpha((255 * alphaStep / 4).round()),
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Light grayscale tone matching the target color's brightness — gives the
  /// zoomed-out canvas a ghost image of the finished artwork.
  Color _grayscalePreview(int number) {
    final target = filledColors[number];
    if (target == null) return Colors.white;
    final luminance =
        0.299 * (target.r * 255) +
        0.587 * (target.g * 255) +
        0.114 * (target.b * 255);
    final v = (150 + luminance * 0.41).round().clamp(0, 255);
    return Color.fromARGB(255, v, v, v);
  }

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

    final viewerScale = transform?.value.getMaxScaleOnAxis() ?? 1.0;
    final gridLineOpacity = 1.0 - (gridFade?.value ?? 0.0);

    // Level of detail by on-screen cell size: below ~14px numbers are
    // unreadable, so hide them and shade unfilled cells with a grayscale
    // preview of their target color instead; fade between the two states.
    final effectiveCell = min(cw, ch) * viewerScale;
    final detail = ((effectiveCell - 14.0) / 8.0).clamp(0.0, 1.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFFF0F0F0),
    );

    final borderPaint = Paint()
      ..color = Color.fromARGB((0x22 * gridLineOpacity).round(), 0, 0, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final highlightPaint = Paint()..color = const Color(0x336C63FF);

    final selectedBorderPaint = Paint()
      ..color = isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final cellGap = 0.5 * gridLineOpacity;

    // Reused per-cell paints — allocating Paint per cell per frame churns the
    // GC during pinch/stroke repaints.
    final cellPaint = Paint();
    final glossPaint = Paint()
      ..color = Colors.white.withAlpha((30 * gridLineOpacity).round());
    final glowPaint = Paint()
      ..color =
          (isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF))
              .withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Numbers share one font size per artwork; quantize the fade so cached
    // TextPainters can be reused across frames.
    final textScale = min(1.0, cw / 28);
    final fontSize = (11.0 * textScale).clamp(6.0, 14.0);
    final detailStep = (detail * 4).round();

    // Only paint cells inside the visible (transformed) clip — when zoomed
    // in, this skips the vast majority of the grid.
    final clip = canvas.getLocalClipBounds();
    final firstRow = max(0, (clip.top / ch).floor());
    final lastRow = min(gridHeight - 1, (clip.bottom / ch).ceil());
    final firstCol = max(0, (clip.left / cw).floor());
    final lastCol = min(gridWidth - 1, (clip.right / cw).ceil());

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
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
          cellPaint.color = filledColors[expectedNumber] ?? Colors.grey;
          canvas.drawRect(rect, cellPaint);
          if (colorblindMode) {
            _drawPattern(canvas, rect, expectedNumber, cw, ch);
          }

          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.3),
            glossPaint,
          );
        } else if (expectedNumber == 0) {
          cellPaint.color = const Color(0xFFE8E8E8);
          canvas.drawRect(rect, cellPaint);
        } else {
          cellPaint.color = Color.lerp(
            _grayscalePreview(expectedNumber),
            Colors.white,
            detail,
          )!;
          canvas.drawRect(rect, cellPaint);
          if (colorblindMode) {
            _drawPattern(canvas, rect, expectedNumber, cw, ch);
          }
        }

        if (isHighlighted && !isFilled && expectedNumber > 0) {
          canvas.drawRect(rect, highlightPaint);
        }

        canvas.drawRect(rect, borderPaint);

        if (isSelected && !isFilled && expectedNumber > 0) {
          canvas.drawRect(rect.deflate(1), selectedBorderPaint);
          canvas.drawRect(rect.deflate(1), glowPaint);
        }

        if (showNumbers && !isFilled && expectedNumber > 0 && detailStep > 0) {
          final tp = _numberPainter(expectedNumber, fontSize, detailStep);
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
