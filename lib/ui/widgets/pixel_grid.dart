import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import '../../config/flavor.dart';
import '../../providers/coloring_provider.dart';
import 'fill_grow_controller.dart';

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

  /// Drives the per-cell "grow in" animation on freshly tapped cells. Also the
  /// painter's repaint source while cells animate. Null disables the effect.
  final FillGrowController? fillGrow;

  final void Function(int row, int col) onCellTap;
  final void Function(int row, int col)? onCellLongPress;
  final VoidCallback? onCellDragStart;
  final void Function(int row, int col)? onCellDrag;
  final VoidCallback? onCellDragEnd;
  final VoidCallback? onCellDragCancel;

  /// Toggles single-finger canvas panning for the current stroke. Called with
  /// `true` when a swipe begins over a non-selected cell (move the artwork) and
  /// `false` when that stroke ends (back to swipe-to-fill).
  final void Function(bool enabled)? onRequestCanvasPan;

  const PixelGrid({
    super.key,
    required this.provider,
    required this.cellSize,
    required this.brushSize,
    required this.isEraseMode,
    required this.colorblindMode,
    this.gridFade,
    this.transform,
    this.fillGrow,
    required this.onCellTap,
    this.onCellLongPress,
    this.onCellDragStart,
    this.onCellDrag,
    this.onCellDragEnd,
    this.onCellDragCancel,
    this.onRequestCanvasPan,
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

  /// When the active single-finger stroke started over a non-selected cell it
  /// moves the canvas (via InteractiveViewer) instead of painting.
  bool _strokeIsPan = false;

  // Swipe-to-fill listens to raw pointer events instead of a pan gesture so
  // it never enters the gesture arena: a pan recognizer here would claim the
  // first finger and starve InteractiveViewer's two-finger pinch-zoom.
  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1) {
      _downPosition = event.position;
      // Decide the gesture's intent from the cell under the finger: a swipe
      // that starts on the selected number paints; anywhere else it pans.
      _strokeIsPan = _shouldPanFrom(event.position);
      if (_strokeIsPan) widget.onRequestCanvasPan?.call(true);
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
    // A pan stroke is driven by the InteractiveViewer, not by painting.
    if (_strokeIsPan) return;
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
    if (_activePointers == 0 && _strokeIsPan) {
      _strokeIsPan = false;
      widget.onRequestCanvasPan?.call(false);
    }
  }

  /// True when a swipe beginning at [globalPos] should move the canvas rather
  /// than paint: outside the grid, in magic-wand mode, over a cell whose number
  /// isn't the selected one, or over a cell that is already filled. Erase
  /// swipes always paint (erase).
  bool _shouldPanFrom(Offset globalPos) {
    if (widget.isEraseMode) return false;
    final provider = widget.provider;
    if (provider.isMagicWandMode || provider.isBombMode) return true;
    final art = provider.currentArt;
    if (art == null) return false;
    final pos = _gridPos(globalPos, art);
    if (pos == null) return true;
    final (row, col) = pos;
    if (provider.filledGrid[row][col] > 0) return true;
    return art.grid[row][col] != provider.selectedNumber;
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    // A single-finger tap fills a cell and a single-finger drag paints along
    // its path (swipe-to-fill); two fingers pan and pinch-zoom the canvas.
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
                  fillGrow: widget.fillGrow,
                  hoverRow: _hoverRow,
                  hoverCol: _hoverCol,
                  gemStyle:
                      FlavorConfig.current.cellStyle == CellRenderStyle.gem,
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
  final FillGrowController? fillGrow;
  final int? hoverRow;
  final int? hoverCol;

  /// When true, filled cells render as faceted gems (diamond-painting flavor)
  /// instead of flat squares. Resolved once from [FlavorConfig] in build().
  final bool gemStyle;

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
    this.fillGrow,
    this.hoverRow,
    this.hoverCol,
    this.gemStyle = false,
  }) : super(repaint: Listenable.merge([gridFade, transform, fillGrow]));

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

  // Gem rendering tuning — kept as named constants for quick visual iteration.
  static const double _gemRingWidth = 0.18; // stroke width as fraction of radius
  static const double _gemRingRadius = 0.9; // bevel-ring radius as fraction of r
  static const double _gemHighlightOffset = 0.35; // specular dot offset from center
  static const int _gemHighlightCoreAlpha = 160;
  static const int _gemHighlightHaloAlpha = 90;

  /// Paints a filled cell as a round faceted "drill": a colored circle, a
  /// darker bevel ring for depth, and a stacked white specular highlight in the
  /// upper-left. Reuses [cellPaint] (no per-cell Paint allocation) and uses only
  /// cheap circle ops — no blur/shaders — to stay within the LOD draw budget.
  void _drawGem(Canvas canvas, Rect rect, Color base, Paint cellPaint) {
    final c = rect.center;
    final r = rect.shortestSide / 2;

    // 1. Body.
    cellPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = base;
    canvas.drawCircle(c, r, cellPaint);

    // 2. Bevel ring for depth.
    cellPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * _gemRingWidth
      ..color = _darken(base, 0.25);
    canvas.drawCircle(c, r * _gemRingRadius, cellPaint);
    cellPaint.style = PaintingStyle.fill;

    // 3. Specular highlight (halo then core), upper-left.
    final hl = Offset(c.dx - r * _gemHighlightOffset, c.dy - r * _gemHighlightOffset);
    cellPaint.color = Colors.white.withAlpha(_gemHighlightHaloAlpha);
    canvas.drawCircle(hl, r * 0.45, cellPaint);
    cellPaint.color = Colors.white.withAlpha(_gemHighlightCoreAlpha);
    canvas.drawCircle(hl, r * 0.28, cellPaint);
  }

  /// Scales an RGB color toward black by [amount] (0..1) for the bevel ring.
  static Color _darken(Color color, double amount) {
    final f = 1.0 - amount;
    return Color.fromARGB(
      (color.a * 255).round(),
      (color.r * 255 * f).round().clamp(0, 255),
      (color.g * 255 * f).round().clamp(0, 255),
      (color.b * 255 * f).round().clamp(0, 255),
    );
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
    // XL grids (96+) zoom deeper, so their labels render proportionally
    // bigger on screen; pull them back one point.
    final xlGrid = max(gridWidth, gridHeight) >= 96;
    final fontSize = (9.0 * textScale).clamp(4.0, 12.0) - (xlGrid ? 1.0 : 0.0);
    final detailStep = (detail * 4).round();

    // Only paint cells inside the visible (transformed) clip — when zoomed
    // in, this skips the vast majority of the grid.
    final clip = canvas.getLocalClipBounds();
    final firstRow = max(0, (clip.top / ch).floor());
    final lastRow = min(gridHeight - 1, (clip.bottom / ch).ceil());
    final firstCol = max(0, (clip.left / cw).floor());
    final lastCol = min(gridWidth - 1, (clip.right / cw).ceil());

    // Fully zoomed out there are no numbers, borders are sub-pixel, and on
    // 96/128 grids every cell is visible — per-cell drawRect would be ~50k
    // ops per pinch frame. Batch cells by color into one drawRawPoints call
    // each (~a dozen draw calls total) instead.
    if (detailStep == 0 && !colorblindMode) {
      _paintLowDetail(canvas, cw, ch, firstRow, lastRow, firstCol, lastCol);
      _paintNextFillable(canvas, cw, ch, cellGap);
      _paintEdge(canvas, size);
      return;
    }

    // Single clock read for any cells currently growing in (taps only).
    final nowMs = fillGrow == null ? 0 : DateTime.now().millisecondsSinceEpoch;

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
          final color = filledColors[expectedNumber] ?? Colors.grey;
          final grow = fillGrow == null
              ? 1.0
              : fillGrow!.factor(row, col, nowMs);
          // While growing in, paint the preview underneath and scale the
          // colour up from the cell centre so it reads as the colour dropping
          // onto the numbered cell.
          final drawRect = grow < 1.0
              ? Rect.fromCenter(
                  center: rect.center,
                  width: rect.width * (0.12 + 0.88 * grow),
                  height: rect.height * (0.12 + 0.88 * grow),
                )
              : rect;
          if (grow < 1.0) {
            cellPaint.color = Color.lerp(
              _grayscalePreview(expectedNumber),
              Colors.white,
              detail,
            )!;
            canvas.drawRect(rect, cellPaint);
          }
          if (gemStyle) {
            _drawGem(canvas, drawRect, color, cellPaint);
            if (colorblindMode) {
              _drawPattern(canvas, drawRect, expectedNumber, cw, ch);
            }
          } else {
            cellPaint.color = color;
            canvas.drawRect(drawRect, cellPaint);
            if (colorblindMode) {
              _drawPattern(canvas, drawRect, expectedNumber, cw, ch);
            }

            canvas.drawRect(
              Rect.fromLTWH(
                drawRect.left,
                drawRect.top,
                drawRect.width,
                drawRect.height * 0.3,
              ),
              glossPaint,
            );
          }
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

    _paintNextFillable(canvas, cw, ch, cellGap);

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

    _paintEdge(canvas, size);
  }

  /// Zoomed-out fast path: one drawRawPoints call per distinct color
  /// (square stroke caps render each point as a cell-sized square).
  void _paintLowDetail(
    Canvas canvas,
    double cw,
    double ch,
    int firstRow,
    int lastRow,
    int firstCol,
    int lastCol,
  ) {
    final batches = <int, List<double>>{};
    final highlightPoints = <double>[];

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final expectedNumber = art.grid[row][col] as int;
        final int colorValue;
        if (filledGrid[row][col] > 0) {
          colorValue = (filledColors[expectedNumber] ?? Colors.grey)
              .toARGB32();
        } else if (expectedNumber == 0) {
          colorValue = 0xFFE8E8E8;
        } else {
          colorValue = _grayscalePreview(expectedNumber).toARGB32();
          if (highlightedNumber != null &&
              expectedNumber == highlightedNumber) {
            highlightPoints
              ..add(col * cw + cw / 2)
              ..add(row * ch + ch / 2);
          }
        }
        batches.putIfAbsent(colorValue, () => <double>[])
          ..add(col * cw + cw / 2)
          ..add(row * ch + ch / 2);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = min(cw, ch);
    for (final entry in batches.entries) {
      paint.color = Color(entry.key);
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(entry.value),
        paint,
      );
    }
    if (highlightPoints.isNotEmpty) {
      paint.color = const Color(0x336C63FF);
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(highlightPoints),
        paint,
      );
    }
  }

  void _paintNextFillable(Canvas canvas, double cw, double ch, double cellGap) {
    if (nextFillable == null || isEraseMode) return;
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

  void _paintEdge(Canvas canvas, Size size) {
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
