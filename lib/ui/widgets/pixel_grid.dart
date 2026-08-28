import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import '../../config/flavor.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';
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
  /// In gem mode its timestamps additionally feed the shader's fill-age
  /// texture (settle pop / glint / afterglow / swipe wave).
  final FillGrowController? fillGrow;

  /// Progress (0..1) of the section-complete shimmer sweep across the board.
  /// Idle at 1.0; the coloring screen runs it forward when a color finishes.
  final Animation<double>? sectionShimmer;

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
  final ValueNotifier<Offset>? tiltNotifier;

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
    this.sectionShimmer,
    required this.onCellTap,
    this.onCellLongPress,
    this.onCellDragStart,
    this.onCellDrag,
    this.onCellDragEnd,
    this.onCellDragCancel,
    this.onRequestCanvasPan,
    this.tiltNotifier,
  });

  /// Warms the gem fragment shader. Call from main() for the gem flavor so
  /// the program is compiled before the first grid frame; otherwise that
  /// frame falls back to the (expensive) CPU whole-grid bake.
  static Future<void> preloadGemShader() =>
      _PixelGridState.preloadGemShader();

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
  bool _strokeIsPan = false;

  static ui.FragmentProgram? _gemShaderProgram;
  static Future<void>? _shaderLoad;

  /// Loads the gem fragment shader once per process. Safe to call repeatedly;
  /// concurrent callers share one load, and a failed load allows a retry.
  static Future<void> preloadGemShader() {
    return _shaderLoad ??=
        ui.FragmentProgram.fromAsset('shaders/gem_grid.frag').then((program) {
      _gemShaderProgram = program;
    }).catchError((Object e) {
      debugPrint('Error loading gem GLSL shader: $e');
      _shaderLoad = null;
    });
  }

  @override
  void initState() {
    super.initState();
    // Normally already warm via main(); this is the fallback path.
    if (_gemShaderProgram == null) {
      preloadGemShader().then((_) {
        if (mounted && _gemShaderProgram != null) setState(() {});
      });
    }
  }

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
              child: SizedBox(
                key: _gridKey,
                width: art.gridWidth * widget.cellSize,
                height: art.gridHeight * widget.cellSize,
                child: _buildCanvas(art),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _PixelGridPainter _buildPainter(dynamic art, _GridLayer layer) {
    return _PixelGridPainter(
      layer: layer,
      art: art,
      filledGrid: widget.provider.filledGrid,
      filledColors: widget.provider.filledColors,
      selectedNumber: widget.provider.selectedNumber,
      showNumbers: widget.provider.showNumbers,
      highlightedNumber: widget.provider.highlightedNumber,
      cellSize: widget.cellSize,
      isEraseMode: widget.isEraseMode,
      brushSize: widget.brushSize,
      colorblindMode: widget.colorblindMode,
      gridFade: widget.gridFade,
      transform: widget.transform,
      fillGrow: widget.fillGrow,
      sectionShimmer: widget.sectionShimmer,
      hoverRow: _hoverRow,
      hoverCol: _hoverCol,
      gemStyle: FlavorConfig.current.cellStyle == CellRenderStyle.gem,
      tiltNotifier: widget.tiltNotifier,
      shaderProgram: _gemShaderProgram,
      fillVersion: widget.provider.fillVersion,
    );
  }

  Widget _buildCanvas(dynamic art) {
    if (FlavorConfig.current.cellStyle != CellRenderStyle.gem) {
      return CustomPaint(
        isComplex: true,
        willChange: false,
        painter: _buildPainter(art, _GridLayer.full),
      );
    }
    // Gem mode paints in two isolated layers: the art body (repaints per
    // tilt/zoom tick — on the GPU path that's just one shader quad) and the
    // labels/selection overlay (repaints on fills and selection changes).
    // Without the split, every accelerometer tick re-ran the full label pass
    // and every fill re-drew the body twice.
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: false,
            painter: _buildPainter(art, _GridLayer.gemBase),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            willChange: false,
            painter: _buildPainter(art, _GridLayer.gemOverlay),
          ),
        ),
      ],
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

/// Which slice of the grid a painter instance draws. Gem mode splits the
/// canvas into an art-body layer and a labels/selection overlay so each can
/// repaint on its own triggers; flat flavors keep the single full painter.
enum _GridLayer { full, gemBase, gemOverlay }

class _PixelGridPainter extends CustomPainter {
  final _GridLayer layer;
  final dynamic art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;
  final int selectedNumber;
  final bool showNumbers;
  final int? highlightedNumber;
  final double cellSize;
  final bool isEraseMode;
  final int brushSize;
  final bool colorblindMode;
  final Animation<double>? gridFade;
  final ValueListenable<Matrix4>? transform;
  final FillGrowController? fillGrow;
  final Animation<double>? sectionShimmer;
  final int? hoverRow;
  final int? hoverCol;

  /// When true, filled cells render as faceted gems (diamond-painting flavor)
  /// instead of flat squares. Resolved once from [FlavorConfig] in build().
  final bool gemStyle;
  final ValueNotifier<Offset>? tiltNotifier;
  final ui.FragmentProgram? shaderProgram;

  /// Monotonic counter from the provider that bumps on every fill (and on art
  /// load). Used as the cache key for the baked gem picture and the shader's
  /// grid texture so neither is regenerated while the fill is unchanged —
  /// cheaper and more reliable than rescanning all cells for a hash each frame.
  final int fillVersion;

  _PixelGridPainter({
    this.layer = _GridLayer.full,
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.selectedNumber,
    required this.showNumbers,
    required this.highlightedNumber,
    required this.cellSize,
    required this.isEraseMode,
    required this.brushSize,
    required this.colorblindMode,
    this.gridFade,
    this.transform,
    this.fillGrow,
    this.sectionShimmer,
    this.hoverRow,
    this.hoverCol,
    this.gemStyle = false,
    this.tiltNotifier,
    this.shaderProgram,
    this.fillVersion = 0,
  }) : super(
          // Each layer repaints only on its own triggers: tilt ticks must not
          // re-run the overlay label pass, and fill-grow animation frames must
          // not re-draw the label pass either. The gem base listens to
          // fillGrow/sectionShimmer because they clock the shader's fill and
          // shimmer animations (a repaint there is one shader-quad draw).
          repaint: Listenable.merge(switch (layer) {
            _GridLayer.full => [
                gridFade,
                transform,
                fillGrow,
                tiltNotifier,
                sectionShimmer,
              ],
            _GridLayer.gemBase => [
                gridFade,
                transform,
                tiltNotifier,
                fillGrow,
                sectionShimmer,
              ],
            _GridLayer.gemOverlay => [gridFade, transform, fillGrow],
          }),
        );

  /// Laid-out number labels, cached across frames and painter instances.
  /// Keyed by number, font size, and the quantized LOD fade step — without
  /// this, every visible cell allocated and laid out a TextPainter per frame.
  static final Map<int, TextPainter> _textCache = {};

  static TextPainter _numberPainter(int number, double fontSize, int alphaStep, {bool isContrast = false}) {
    final textColor = isContrast ? Colors.white : const Color(0xFF555555);
    final key = (isContrast ? 1000000 : 0) + number * 10000 + (fontSize * 10).round() * 10 + alphaStep;
    return _textCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            color: textColor.withAlpha((255 * alphaStep / 4).round()),
            fontSize: fontSize,
            fontWeight: isContrast ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Unfilled-cell preview colors (grayscale ghost of the target color, faded
  /// toward white by the quantized LOD step), cached across frames and painter
  /// instances — computing these per cell per frame allocated thousands of
  /// Colors per pinch/stroke frame on large grids.
  static final Map<int, Color> _previewCache = {};

  Color _previewColor(int number, int detailStep) {
    final target = filledColors[number];
    if (target == null) return Colors.white;
    final argb = target.toARGB32();
    return _previewCache.putIfAbsent(argb * 8 + detailStep, () {
      final luminance =
          0.299 * (target.r * 255) +
          0.587 * (target.g * 255) +
          0.114 * (target.b * 255);
      final v = (150 + luminance * 0.41).round().clamp(0, 255);
      final gray = Color.fromARGB(255, v, v, v);
      if (detailStep <= 0) return gray;
      return Color.lerp(gray, Colors.white, detailStep / 4)!;
    });
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

  static ui.Picture? _overlayStaticPicture;
  static String _overlayArtId = '';
  static int _overlayFillVersion = -1;
  static int _overlayDetailStep = -1;
  static int _overlaySelected = -1;
  static int _overlayHighlighted = -2; // -1 encodes "no highlight"
  static bool _overlayShowNumbers = false;
  static double _overlayWidth = 0.0;
  static double _overlayHeight = 0.0;

  /// Records the overlay's static content — selection/highlight tints and
  /// number labels for every unfilled cell — once per (fill, selection,
  /// LOD-bucket) state. Replaying one picture per frame replaces hundreds of
  /// TextPainter.paint calls during pans; the engine culls off-clip ops.
  void _ensureOverlayStatics(
    Size size,
    double cw,
    double ch,
    double cellGap,
    int detailStep,
  ) {
    final highlightKey = highlightedNumber ?? -1;
    if (_overlayStaticPicture != null &&
        _overlayArtId == art.id &&
        _overlayFillVersion == fillVersion &&
        _overlayDetailStep == detailStep &&
        _overlaySelected == selectedNumber &&
        _overlayHighlighted == highlightKey &&
        _overlayShowNumbers == showNumbers &&
        _overlayWidth == size.width &&
        _overlayHeight == size.height) {
      return;
    }

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final fontSize = (cw * 0.38).clamp(2.0, 7.5);
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final highlightPaint = Paint()..color = const Color(0x336C63FF);
    final darkPreviewPaint = Paint()..color = const Color(0xFF808080);

    for (var row = 0; row < gridHeight; row++) {
      for (var col = 0; col < gridWidth; col++) {
        final expectedNumber = art.grid[row][col] as int;
        if (expectedNumber == 0 || filledGrid[row][col] > 0) continue;
        final isSelected = expectedNumber == selectedNumber;
        final isHighlighted =
            highlightedNumber != null && expectedNumber == highlightedNumber;

        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );

        if (isSelected) {
          c.drawRect(rect, darkPreviewPaint);
        } else if (isHighlighted) {
          c.drawRect(rect, highlightPaint);
        }
        if (showNumbers && detailStep > 0) {
          final tp = _numberPainter(
            expectedNumber,
            fontSize,
            detailStep,
            isContrast: isSelected || isHighlighted,
          );
          tp.paint(
            c,
            Offset(
              col * cw + (cw - tp.width) / 2,
              row * ch + (ch - tp.height) / 2,
            ),
          );
        }
      }
    }

    _overlayStaticPicture = recorder.endRecording();
    _overlayArtId = art.id as String;
    _overlayFillVersion = fillVersion;
    _overlayDetailStep = detailStep;
    _overlaySelected = selectedNumber;
    _overlayHighlighted = highlightKey;
    _overlayShowNumbers = showNumbers;
    _overlayWidth = size.width;
    _overlayHeight = size.height;
  }

  // Gem rendering tuning — kept as named constants for quick visual iteration.
  static const double _gemRingWidth = 0.18; // stroke width as fraction of radius
  static const double _gemHighlightOffset = 0.35; // specular dot offset from center
  static const int _gemHighlightCoreAlpha = 160;
  static const int _gemHighlightHaloAlpha = 90;

  /// Draws the static 3D body of a gem cell (drop shadow, 3D dome gradient, bevel, facet cuts).
  /// This heavy geometry is recorded into an offscreen [ui.Picture] cache.
  void _drawGemBase(Canvas canvas, Rect rect, Color base, Paint cellPaint, double effectiveCell) {
    final c = rect.center;
    final r = rect.shortestSide / 2;

    // 1. Zoomed out LOD (< 10.0): Fast flat rounded tile
    if (effectiveCell < 10.0) {
      cellPaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = base;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), cellPaint);
      return;
    }

    const shiftX = -0.707;
    const shiftY = -0.707;

    // 2. Ambient Drop Shadow (gives 3D depth above the canvas grid)
    final shadowOffset = Offset(c.dx - shiftX * r * 0.08, c.dy - shiftY * r * 0.08);
    cellPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = const Color(0x35000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: shadowOffset, width: rect.width, height: rect.height),
        const Radius.circular(3),
      ),
      cellPaint,
    );

    // 3. 3D Spherical Radial Gradient Body
    final focalOffset = Offset(c.dx + r * shiftX * 0.3, c.dy + r * shiftY * 0.3);
    final lightShade = _lighten(base, 0.38);
    final darkShade = _darken(base, 0.45);

    cellPaint
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        focalOffset,
        r * 1.15,
        [lightShade, base, darkShade],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), cellPaint);
    cellPaint.shader = null;

    // Bevel outer ring for edge definition
    cellPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * _gemRingWidth)
      ..color = darkShade.withAlpha(160);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), cellPaint);
    cellPaint.style = PaintingStyle.fill;

    // 4. Tier 3 High Detail: Octagonal Table Cut & 8 Facet Crown Seams (Zoom >= 16.0)
    if (effectiveCell >= 16.0) {
      final facetPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.07);

      final tableRadius = r * 0.44;
      final tableCenter = Offset(c.dx + shiftX * r * 0.08, c.dy + shiftY * r * 0.08);

      // Octagonal Table Path
      final octPath = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + pi / 8;
        final px = tableCenter.dx + tableRadius * cos(a);
        final py = tableCenter.dy + tableRadius * sin(a);
        if (i == 0) {
          octPath.moveTo(px, py);
        } else {
          octPath.lineTo(px, py);
        }
      }
      octPath.close();

      // 8 radial crown facet lines from octagonal corners to rim
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + pi / 8;
        final cosA = cos(a);
        final sinA = sin(a);

        final p1 = Offset(tableCenter.dx + tableRadius * cosA, tableCenter.dy + tableRadius * sinA);
        final p2 = Offset(c.dx + (r * 0.90) * cosA, c.dy + (r * 0.90) * sinA);

        facetPaint.color = (i < 4) ? Colors.white.withAlpha(60) : darkShade.withAlpha(100);
        canvas.drawLine(p1, p2, facetPaint);
      }

      // Flat Octagonal Table Facet Cut
      cellPaint
        ..style = PaintingStyle.fill
        ..color = lightShade.withAlpha(70);
      canvas.drawPath(octPath, cellPaint);

      cellPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.9, r * 0.06)
        ..color = Colors.white.withAlpha(90);
      canvas.drawPath(octPath, cellPaint);
      cellPaint.style = PaintingStyle.fill;
    }

    // Secondary Rim Bounce Light (bottom opposite edge)
    final bounceHL = Offset(
      c.dx - r * _gemHighlightOffset * shiftX * 0.8,
      c.dy - r * _gemHighlightOffset * shiftY * 0.8,
    );
    cellPaint.color = lightShade.withAlpha(45);
    canvas.drawCircle(bounceHL, r * 0.25, cellPaint);
  }

  /// Draws the lightweight dynamic specular highlight dot & star glare flare.
  /// Shifted dynamically per frame based on [shiftX] and [shiftY] from tilt/position.
  void _drawGemHighlight(Canvas canvas, Rect rect, Paint cellPaint, double effectiveCell, double shiftX, double shiftY) {
    if (effectiveCell < 10.0) return;

    final c = rect.center;
    final r = rect.shortestSide / 2;

    final hl = Offset(
      c.dx + r * _gemHighlightOffset * shiftX * 1.25,
      c.dy + r * _gemHighlightOffset * shiftY * 1.25,
    );

    // Soft Specular Halo
    cellPaint.color = Colors.white.withAlpha(_gemHighlightHaloAlpha);
    canvas.drawCircle(hl, r * 0.42, cellPaint);

    // Sharp Core Specular Highlight
    cellPaint.color = Colors.white.withAlpha(_gemHighlightCoreAlpha);
    canvas.drawCircle(hl, r * 0.24, cellPaint);

    // 4-Point Specular Star Flare for extra diamond glint (Zoom >= 24.0)
    if (effectiveCell >= 24.0) {
      final flarePaint = Paint()
        ..color = Colors.white.withAlpha(210)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.08);

      final flareSize = r * 0.35;
      canvas.drawLine(
        Offset(hl.dx - flareSize, hl.dy),
        Offset(hl.dx + flareSize, hl.dy),
        flarePaint,
      );
      canvas.drawLine(
        Offset(hl.dx, hl.dy - flareSize),
        Offset(hl.dx, hl.dy + flareSize),
        flarePaint,
      );
    }
  }

  /// Scales an RGB color toward black by [amount] (0..1) for the bevel ring.
  /// Cached by source color — the gem path calls this for every filled cell
  /// on every repaint. (All callers use the same amount, so it isn't keyed.)
  static final Map<int, Color> _darkenCache = {};

  static Color _darken(Color color, double amount) {
    return _darkenCache.putIfAbsent(color.toARGB32(), () {
      final f = 1.0 - amount;
      return Color.fromARGB(
        (color.a * 255).round(),
        (color.r * 255 * f).round().clamp(0, 255),
        (color.g * 255 * f).round().clamp(0, 255),
        (color.b * 255 * f).round().clamp(0, 255),
      );
    });
  }

  static final Map<int, Color> _lightenCache = {};

  static Color _lighten(Color color, double amount) {
    return _lightenCache.putIfAbsent(color.toARGB32(), () {
      final r = (color.r * 255 + (255 - color.r * 255) * amount).round().clamp(0, 255);
      final g = (color.g * 255 + (255 - color.g * 255) * amount).round().clamp(0, 255);
      final b = (color.b * 255 + (255 - color.b * 255) * amount).round().clamp(0, 255);
      return Color.fromARGB((color.a * 255).round(), r, g, b);
    });
  }

  static ui.Picture? _bakedBasePicture;
  static int _bakedFillVersion = -1;
  static bool _bakedLowDetail = false;
  static String _bakedArtId = '';
  static double _bakedWidth = 0.0;
  static double _bakedHeight = 0.0;

  // GPU fast path: a small grid-sized image (one texel per cell) that encodes
  // the full board state in alpha — 0 = empty cell, ~0.5 = unfilled numbered
  // cell (rgb carries the grayscale ghost-preview color), 1.0 = filled (rgb
  // carries the fill color). The gem fragment shader renders every zoom level
  // from this alone, so a fill rewrites texels instead of re-recording any
  // CPU picture. Rebuilt only when the fill actually changes — keyed on
  // fillVersion (+ art and dimensions), never a per-frame full-grid scan.
  static ui.Image? _cachedGridImage;
  static int _cachedImageFillVersion = -1;
  static String _cachedImageArtId = '';
  static int _cachedImageW = 0;
  static int _cachedImageH = 0;

  // The unfilled-preview texels never change for a given artwork, so they are
  // recorded once per art and replayed under the filled texels on rebuilds,
  // keeping the per-fill rebuild cost proportional to the filled count.
  static ui.Picture? _previewLayerPicture;
  static String _previewLayerArtId = '';

  // Companion age texture for the shader's fill animations: each texel's red
  // channel holds that cell's age at bake time over a [_fillAnimWindowMs]
  // window (255 = long done). The shader adds uTime (seconds since the bake)
  // so animations advance frame-by-frame without any texture rebuilds.
  static const int _fillAnimWindowMs = 1600;
  static ui.Image? _cachedAgeImage;
  static int _ageEpochMs = 0;

  void _updateGridTextureIfNeeded() {
    final width = art.gridWidth as int;
    final height = art.gridHeight as int;
    if (_cachedGridImage != null &&
        _cachedImageFillVersion == fillVersion &&
        _cachedImageArtId == art.id &&
        _cachedImageW == width &&
        _cachedImageH == height) {
      return;
    }

    // Texels must stay exact: no anti-aliased edges bleeding into neighbors.
    final paint = Paint()..isAntiAlias = false;

    if (_previewLayerPicture == null || _previewLayerArtId != art.id) {
      final previewRecorder = ui.PictureRecorder();
      final pc = Canvas(previewRecorder);
      for (var r = 0; r < height; r++) {
        for (var col = 0; col < width; col++) {
          final expectedNumber = art.grid[r][col] as int;
          if (expectedNumber <= 0) continue;
          paint.color = _previewColor(expectedNumber, 0).withAlpha(128);
          pc.drawRect(
            Rect.fromLTWH(col.toDouble(), r.toDouble(), 1.0, 1.0),
            paint,
          );
        }
      }
      _previewLayerPicture = previewRecorder.endRecording();
      _previewLayerArtId = art.id as String;
    }

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawPicture(_previewLayerPicture!);
    for (var r = 0; r < height; r++) {
      final row = filledGrid[r];
      for (var col = 0; col < width; col++) {
        if (row[col] > 0) {
          // Match the CPU fallback: colour a filled cell by its expected
          // number so both render paths look identical.
          final expectedNumber = art.grid[r][col] as int;
          paint.color =
              filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
          c.drawRect(
            Rect.fromLTWH(col.toDouble(), r.toDouble(), 1.0, 1.0),
            paint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    _cachedGridImage?.dispose();
    _cachedGridImage = picture.toImageSync(width, height);
    picture.dispose();
    _cachedImageFillVersion = fillVersion;
    _cachedImageArtId = art.id;
    _cachedImageW = width;
    _cachedImageH = height;

    _rebuildAgeTexture(width, height);
  }

  /// Bakes the per-cell fill-age texture from [fillGrow]'s timestamps. Cost is
  /// one full-rect draw plus a rect per *recently* filled cell (the registry
  /// is capped), and it only runs when the color texture rebuilds anyway.
  void _rebuildAgeTexture(int width, int height) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;

    // Default every cell to "finished" (255) so only fresh fills animate.
    paint.color = const Color(0xFFFFFFFF);
    c.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    fillGrow?.forEachActive((row, col, startMs) {
      final ageMs = nowMs - startMs;
      if (ageMs >= _fillAnimWindowMs) return;
      final enc = (ageMs * 255 ~/ _fillAnimWindowMs).clamp(0, 255);
      paint.color = Color.fromARGB(255, enc, 0, 0);
      c.drawRect(
        Rect.fromLTWH(col.toDouble(), row.toDouble(), 1.0, 1.0),
        paint,
      );
    });

    final picture = recorder.endRecording();
    _cachedAgeImage?.dispose();
    _cachedAgeImage = picture.toImageSync(width, height);
    picture.dispose();
    _ageEpochMs = nowMs;
  }

  /// Shared level-of-detail math for all layers.
  (double, double, double, double, int, double) _layout(Size size) {
    final cw = size.width / (art.gridWidth as int);
    final ch = size.height / (art.gridHeight as int);
    final viewerScale = transform?.value.getMaxScaleOnAxis() ?? 1.0;
    final gridLineOpacity = 1.0 - (gridFade?.value ?? 0.0);
    final cellGap = 0.2 * gridLineOpacity;
    final effectiveCell = min(cw, ch) * viewerScale;
    final detail = ((effectiveCell - 14.0) / 8.0).clamp(0.0, 1.0);
    final detailStep = (detail * 4).round();
    return (cw, ch, cellGap, effectiveCell, detailStep, gridLineOpacity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (layer) {
      case _GridLayer.gemBase:
        _paintGemBase(canvas, size);
      case _GridLayer.gemOverlay:
        _paintGemOverlay(canvas, size);
      case _GridLayer.full:
        _paintFull(canvas, size);
    }
  }

  /// Gem art body: one fragment-shader draw on the GPU path, or the baked
  /// whole-grid picture when the shader is unavailable / colorblind mode
  /// needs CPU-drawn accessibility patterns.
  void _paintGemBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    if (shaderProgram != null && !colorblindMode) {
      _updateGridTextureIfNeeded();
      final gridImage = _cachedGridImage;
      final ageImage = _cachedAgeImage;
      if (gridImage != null && ageImage != null) {
        final shader = shaderProgram!.fragmentShader();
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, gridWidth.toDouble());
        shader.setFloat(3, gridHeight.toDouble());
        final tilt = tiltNotifier?.value ?? Offset.zero;
        shader.setFloat(4, tilt.dx);
        shader.setFloat(5, tilt.dy);
        shader.setFloat(6, effectiveCell);
        // Seconds since the age texture was baked — clocks fill animations.
        shader.setFloat(
          7,
          (DateTime.now().millisecondsSinceEpoch - _ageEpochMs) / 1000.0,
        );
        shader.setFloat(8, sectionShimmer?.value ?? 1.0);
        shader.setImageSampler(0, gridImage);
        shader.setImageSampler(1, ageImage);

        // Always draw the full grid rect: the canvas clip already limits
        // rasterization, and anchoring the geometry at the canvas origin
        // keeps FlutterFragCoord's cell math identical on every backend.
        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
        return;
      }
    }

    // The baked gem picture only distinguishes "low detail" (unfilled cells
    // drawn as flat preview fills) from detailed (unfilled cells drawn as thin
    // borders), so key the cache on that boolean rather than the full
    // detailStep — otherwise every zoom-threshold crossing re-bakes the whole
    // grid mid-gesture. The fill itself is tracked by fillVersion, which the
    // provider bumps on every fill and on art load, so no per-frame grid scan.
    final lowDetail = detailStep == 0;
    if (_bakedBasePicture == null ||
        _bakedFillVersion != fillVersion ||
        _bakedLowDetail != lowDetail ||
        _bakedArtId != art.id ||
        _bakedWidth != size.width ||
        _bakedHeight != size.height) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);

      recorderCanvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      final recPaint = Paint();
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled = filledGrid[r][c] > 0;
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
            _drawGemBase(recorderCanvas, rect, color, recPaint, effectiveCell);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (detailStep == 0) {
              final previewColor = _previewColor(expectedNumber, 0);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            } else {
              final borderPaint = Paint()
                ..color = const Color(0xFFE0E0E0)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.36;
              recorderCanvas.drawRect(rect, borderPaint);
            }
          }
        }
      }

      _bakedBasePicture = recorder.endRecording();
      _bakedFillVersion = fillVersion;
      _bakedLowDetail = lowDetail;
      _bakedArtId = art.id;
      _bakedWidth = size.width;
      _bakedHeight = size.height;
    }

    canvas.drawPicture(_bakedBasePicture!);
  }

  /// Gem overlay: cached static picture (selection tints + number labels)
  /// plus the tilt-driven specular pass when the base is CPU-baked (the
  /// shader draws its own specular).
  void _paintGemOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final shaderActive =
        shaderProgram != null && !colorblindMode && _cachedGridImage != null;
    if (shaderActive || effectiveCell < 10.0) return;

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final clip = canvas.getLocalClipBounds();
    final firstRow = max(0, (clip.top / ch).floor());
    final lastRow = min(gridHeight - 1, (clip.bottom / ch).ceil());
    final firstCol = max(0, (clip.left / cw).floor());
    final lastCol = min(gridWidth - 1, (clip.right / cw).ceil());
    final tilt = tiltNotifier?.value ?? Offset.zero;
    final shiftX = (-0.707 - tilt.dx * 0.40).clamp(-1.20, 1.20);
    final shiftY = (-0.707 + tilt.dy * 0.40).clamp(-1.20, 1.20);
    final cellPaint = Paint();
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (filledGrid[row][col] <= 0) continue;
        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );
        _drawGemHighlight(canvas, rect, cellPaint, effectiveCell, shiftX, shiftY);
      }
    }
  }

  /// Flat-flavor painter (single layer, unchanged behavior).
  void _paintFull(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, effectiveCell, detailStep, gridLineOpacity) =
        _layout(size);

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

    // Reused per-cell paints
    final cellPaint = Paint();
    final glossPaint = Paint()
      ..color = Colors.white.withAlpha((30 * gridLineOpacity).round());
    final glowPaint = Paint()
      ..color =
          (isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF))
              .withAlpha(36);

    final textScale = min(1.0, cw / 28);
    final xlGrid = max(gridWidth, gridHeight) >= 96;
    final fontSize = (9.0 * textScale).clamp(4.0, 12.0) - (xlGrid ? 1.0 : 0.0);

    final clip = canvas.getLocalClipBounds();
    final firstRow = max(0, (clip.top / ch).floor());
    final lastRow = min(gridHeight - 1, (clip.bottom / ch).ceil());
    final firstCol = max(0, (clip.left / cw).floor());
    final lastCol = min(gridWidth - 1, (clip.right / cw).ceil());

    if (detailStep == 0 && !colorblindMode) {
      _paintLowDetail(canvas, cw, ch, firstRow, lastRow, firstCol, lastCol);
      _paintEdge(canvas, size);
      return;
    }

    final nowMs = fillGrow == null ? 0 : DateTime.now().millisecondsSinceEpoch;

    // Directional vectors for dynamic specular glint highlights
    final matrix = transform?.value;
    double sx = size.width / 2;
    double sy = size.height / 2;
    if (matrix != null) {
      sx = matrix.storage[0] * sx + matrix.storage[12];
      sy = matrix.storage[5] * sy + matrix.storage[13];
    }
    const lightX = 200.0;
    const lightY = -150.0;
    final dx = lightX - sx;
    final dy = lightY - sy;
    final dist = sqrt(dx * dx + dy * dy);
    final double nx = dist > 0 ? dx / dist : -0.707;
    final double ny = dist > 0 ? dy / dist : -0.707;

    final tilt = tiltNotifier?.value ?? Offset.zero;
    final shiftX = (nx - tilt.dx * 0.45).clamp(-1.25, 1.25);
    final shiftY = (ny + tilt.dy * 0.45).clamp(-1.25, 1.25);

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
          final drawRect = grow < 1.0
              ? Rect.fromCenter(
                  center: rect.center,
                  width: rect.width * (0.12 + 0.88 * grow),
                  height: rect.height * (0.12 + 0.88 * grow),
                )
              : rect;
          if (grow < 1.0) {
            cellPaint.color = _previewColor(expectedNumber, detailStep);
            canvas.drawRect(rect, cellPaint);
          }
          if (gemStyle) {
            if (grow < 1.0) {
              _drawGemBase(canvas, drawRect, color, cellPaint, effectiveCell);
            }
            _drawGemHighlight(canvas, drawRect, cellPaint, effectiveCell, shiftX, shiftY);
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

          // Afterglow: a soft warm flash that fades over 450ms after the
          // fill, sharing the grow's clock. Stroke fills carry naturally
          // staggered timestamps, so a swipe leaves a glowing trail.
          final fillStartMs = fillGrow?.startMsOf(row, col);
          if (fillStartMs != null) {
            final age = (nowMs - fillStartMs) / 1000.0;
            if (age >= 0 && age < 0.45) {
              final glow = 1.0 - age / 0.45;
              cellPaint.color = const Color(0xFFFFF3D6)
                  .withAlpha((80 * glow * glow).round());
              canvas.drawRect(drawRect, cellPaint);
            }
          }
        } else if (expectedNumber == 0) {
          cellPaint.color = const Color(0xFFE8E8E8);
          canvas.drawRect(rect, cellPaint);
        } else {
          cellPaint.color = _previewColor(expectedNumber, detailStep);
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

    // Section-complete shimmer: one skewed bright band sweeping the filled
    // cells — the CPU twin of the gem shader's effect. Runs for 600ms only,
    // over visible cells, so the extra rects never outlast the celebration.
    final shimmer = sectionShimmer?.value ?? 1.0;
    if (shimmer > 0.001 && shimmer < 0.999) {
      final band = -0.2 + 1.4 * shimmer;
      final denom = size.width + size.height * 0.35;
      final shimmerPaint = Paint();
      for (var row = firstRow; row <= lastRow; row++) {
        for (var col = firstCol; col <= lastCol; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((115 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(
              col * cw + cellGap,
              row * ch + cellGap,
              cw - cellGap * 2,
              ch - cellGap * 2,
            ),
            shimmerPaint,
          );
        }
      }
    }

    if (hoverRow != null && hoverCol != null) {
      final cursorPaint = Paint()
        ..color =
            (isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF))
                .withAlpha(50);
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
          colorValue = _previewColor(expectedNumber, 0).toARGB32();
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
        ui.PointMode.points,
        Float32List.fromList(entry.value),
        paint,
      );
    }
    if (highlightPoints.isNotEmpty) {
      paint.color = const Color(0x336C63FF);
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(highlightPoints),
        paint,
      );
    }
  }

  void _paintEdge(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(_PixelGridPainter old) =>
      layer != old.layer ||
      fillVersion != old.fillVersion ||
      selectedNumber != old.selectedNumber ||
      showNumbers != old.showNumbers ||
      highlightedNumber != old.highlightedNumber ||
      cellSize != old.cellSize ||
      isEraseMode != old.isEraseMode ||
      brushSize != old.brushSize ||
      colorblindMode != old.colorblindMode ||
      gemStyle != old.gemStyle ||
      hoverRow != old.hoverRow ||
      hoverCol != old.hoverCol ||
      art.id != old.art.id ||
      gridFade != old.gridFade ||
      transform != old.transform ||
      fillGrow != old.fillGrow ||
      sectionShimmer != old.sectionShimmer ||
      tiltNotifier != old.tiltNotifier ||
      shaderProgram != old.shaderProgram;
}
