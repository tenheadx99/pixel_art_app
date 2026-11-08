import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
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
  final bool readOnly;

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

  final void Function(int row, int col)? onCellTap;
  final void Function(int row, int col)? onCellLongPress;
  final VoidCallback? onCellDragStart;
  final void Function(int row, int col)? onCellDrag;
  final VoidCallback? onCellDragEnd;
  final VoidCallback? onCellDragCancel;

  /// Fired with the touch global position and grid coordinate during strokes
  /// so a magnifier loupe can float above the user's finger.
  final void Function(Offset? globalPos, int? row, int? col)? onPointerHoverOrDrag;

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
    this.readOnly = false,
    this.gridFade,
    this.transform,
    this.fillGrow,
    this.sectionShimmer,
    this.onCellTap,
    this.onCellLongPress,
    this.onCellDragStart,
    this.onCellDrag,
    this.onCellDragEnd,
    this.onCellDragCancel,
    this.onPointerHoverOrDrag,
    this.onRequestCanvasPan,
    this.tiltNotifier,
  });

  /// Warms the gem fragment shader. Call from main() for the gem flavor so
  /// the program is compiled before the first grid frame; otherwise that
  /// frame falls back to the (expensive) CPU whole-grid bake.
  static Future<void> preloadGemShader() => _PixelGridState.preloadGemShader();

  /// Warms the cross-stitch fragment shader. Call from main() for the
  /// cross_stitch flavor so the program is compiled before the first grid
  /// frame; otherwise that frame falls back to the (expensive) CPU bake.
  static Future<void> preloadCrossStitchShader() =>
      _PixelGridState.preloadCrossStitchShader();

  /// Warms the flat / plain fragment shader. Call from main() for the
  /// original / flat flavor so the program is compiled before the first grid
  /// frame, ensuring 120 FPS GPU-accelerated rendering.
  static Future<void> preloadFlatShader() =>
      _PixelGridState.preloadFlatShader();

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

  static ui.FragmentProgram? _crossStitchShaderProgram;
  static Future<void>? _crossStitchShaderLoad;

  static ui.FragmentProgram? _flatShaderProgram;
  static Future<void>? _flatShaderLoad;

  /// Loads the gem fragment shader once per process. Safe to call repeatedly;
  /// concurrent callers share one load, and a failed load allows a retry.
  static Future<void> preloadGemShader() {
    return _shaderLoad ??= ui.FragmentProgram.fromAsset('shaders/gem_grid.frag')
        .then((program) {
          _gemShaderProgram = program;
        })
        .catchError((Object e) {
          debugPrint('Error loading gem GLSL shader: $e');
          _shaderLoad = null;
        });
  }

  /// Loads the cross-stitch fragment shader once per process.
  static Future<void> preloadCrossStitchShader() {
    return _crossStitchShaderLoad ??=
        ui.FragmentProgram.fromAsset('shaders/cross_stitch_grid.frag')
            .then((program) {
              _crossStitchShaderProgram = program;
            })
            .catchError((Object e) {
              debugPrint('Error loading cross-stitch GLSL shader: $e');
              _crossStitchShaderLoad = null;
            });
  }

  /// Loads the flat / plain fragment shader once per process.
  static Future<void> preloadFlatShader() {
    return _flatShaderLoad ??=
        ui.FragmentProgram.fromAsset('shaders/flat_grid.frag')
            .then((program) {
              _flatShaderProgram = program;
            })
            .catchError((Object e) {
              debugPrint('Error loading flat GLSL shader: $e');
              _flatShaderLoad = null;
            });
  }

  // Merged per-layer repaint listenables, built once here instead of inside
  // every painter construction — painters are recreated on each provider
  // notify, and allocating a fresh Listenable.merge each time churned
  // listener registrations.
  Listenable? _flatBaseRepaint;
  Listenable? _flatOverlayRepaint;
  Listenable? _gemBaseRepaint;
  Listenable? _gemOverlayRepaint;
  Listenable? _crossStitchBaseRepaint;
  Listenable? _crossStitchOverlayRepaint;
  Listenable? _beadBaseRepaint;
  Listenable? _beadOverlayRepaint;
  Listenable? _brickBaseRepaint;
  Listenable? _brickOverlayRepaint;
  Listenable? _knitBaseRepaint;
  Listenable? _knitOverlayRepaint;
  Listenable? _mosaicBaseRepaint;
  Listenable? _mosaicOverlayRepaint;
  Listenable? _glowBaseRepaint;
  Listenable? _glowOverlayRepaint;
  Listenable? _stickerBaseRepaint;
  Listenable? _stickerOverlayRepaint;
  Listenable? _quiltBaseRepaint;
  Listenable? _quiltOverlayRepaint;
  Listenable? _voxelBaseRepaint;
  Listenable? _voxelOverlayRepaint;

  void _onWaveRevealed() {
    _PixelGridPainter.markWaveDirty();
  }

  void _rebuildRepaintListenables() {
    // Each layer repaints only on its own triggers: tilt ticks must not
    // re-run the overlay label pass, and fill-grow animation frames must
    // not re-draw the label pass either. The gem base listens to
    // fillGrow/sectionShimmer because they clock the shader's fill and
    // shimmer animations (a repaint there is one shader-quad draw). The flat
    // base deliberately does NOT listen to fillGrow's per-frame ticks — only
    // to its `settled` signal (a cell's settled appearance changed) — so the
    // full cell+label pass no longer re-runs at 60fps while fills animate;
    // the flat overlay handles the animated slice.
    _flatBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
    ]);
    _flatOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _gemBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.fillGrow?.newlyRevealed,
      widget.tiltNotifier,
      widget.sectionShimmer,
    ]);
    _gemOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
    ]);
    _crossStitchBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.fillGrow?.newlyRevealed,
      widget.tiltNotifier,
      widget.sectionShimmer,
    ]);
    _crossStitchOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
    ]);
    _beadBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _beadOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _brickBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _brickOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _knitBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _knitOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _mosaicBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _mosaicOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _glowBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _glowOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _stickerBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _stickerOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _quiltBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _quiltOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
    _voxelBaseRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow?.settled,
      widget.fillGrow?.newlyRevealed,
      widget.sectionShimmer,
    ]);
    _voxelOverlayRepaint = Listenable.merge([
      widget.gridFade,
      widget.transform,
      widget.fillGrow,
      widget.sectionShimmer,
    ]);
  }

  @override
  void initState() {
    super.initState();
    widget.fillGrow?.newlyRevealed.addListener(_onWaveRevealed);
    widget.fillGrow?.settled.addListener(_onWaveRevealed);
    _rebuildRepaintListenables();
    // Normally already warm via main(); this is the fallback path.
    if (_gemShaderProgram == null) {
      preloadGemShader().then((_) {
        if (mounted && _gemShaderProgram != null) setState(() {});
      });
    }
    if (_crossStitchShaderProgram == null) {
      preloadCrossStitchShader().then((_) {
        if (mounted && _crossStitchShaderProgram != null) setState(() {});
      });
    }
    if (_flatShaderProgram == null) {
      preloadFlatShader().then((_) {
        if (mounted && _flatShaderProgram != null) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(PixelGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fillGrow != widget.fillGrow) {
      oldWidget.fillGrow?.newlyRevealed.removeListener(_onWaveRevealed);
      oldWidget.fillGrow?.settled.removeListener(_onWaveRevealed);
      widget.fillGrow?.newlyRevealed.addListener(_onWaveRevealed);
      widget.fillGrow?.settled.addListener(_onWaveRevealed);
    }
    if (oldWidget.gridFade != widget.gridFade ||
        oldWidget.transform != widget.transform ||
        oldWidget.fillGrow != widget.fillGrow ||
        oldWidget.tiltNotifier != widget.tiltNotifier ||
        oldWidget.sectionShimmer != widget.sectionShimmer ||
        oldWidget.readOnly != widget.readOnly) {
      _rebuildRepaintListenables();
    }
  }

  @override
  void dispose() {
    widget.fillGrow?.newlyRevealed.removeListener(_onWaveRevealed);
    widget.fillGrow?.settled.removeListener(_onWaveRevealed);
    // The painter keeps static picture/image/text caches so they survive
    // rebuilds; release them when the grid leaves the tree so a long session
    // doesn't accumulate every opened artwork's caches.
    _PixelGridPainter.releaseCaches();
    super.dispose();
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
      // In wand/bomb mode, do not immediately activate canvas pan on pointer down
      // so stationary taps are not swallowed by InteractiveViewer's gesture arena.
      if (_strokeIsPan &&
          !widget.provider.isMagicWandMode &&
          !widget.provider.isBombMode) {
        widget.onRequestCanvasPan?.call(true);
      } else if (!widget.readOnly) {
        final art = widget.provider.currentArt;
        if (art != null) {
          final pos = _gridPos(event.position, art);
          if (pos != null) {
            widget.onPointerHoverOrDrag?.call(event.position, pos.$1, pos.$2);
          }
        }
      }
    } else {
      // Second finger: this is a pinch, not a stroke. Revert any paint.
      _downPosition = null;
      widget.onPointerHoverOrDrag?.call(null, null, null);
      if (_stroking) {
        _stroking = false;
        widget.onCellDragCancel?.call();
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final art = widget.provider.currentArt;
    if (art == null) return;
    if (_activePointers != 1) return;
    final down = _downPosition;
    if (down == null) return;
    final dist = (event.position - down).distance;

    // A pan stroke is driven by the InteractiveViewer, not by painting.
    if (_strokeIsPan) {
      if (dist >= kTouchSlop) {
        widget.onRequestCanvasPan?.call(true);
      }
      return;
    }

    if (widget.readOnly || widget.onCellDrag == null) return;
    final pos = _gridPos(event.position, art);
    if (pos != null) {
      widget.onPointerHoverOrDrag?.call(event.position, pos.$1, pos.$2);
    }
    if (!_stroking) {
      if (dist < kTouchSlop) {
        return;
      }
      _stroking = true;
      widget.onCellDragStart?.call();
      final initialPos = _gridPos(down, art);
      if (initialPos != null) widget.onCellDrag!(initialPos.$1, initialPos.$2);
    }
    if (pos != null) widget.onCellDrag!(pos.$1, pos.$2);
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers = max(0, _activePointers - 1);
    _downPosition = null;
    if (_activePointers == 0) {
      widget.onPointerHoverOrDrag?.call(null, null, null);
    }
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
    if (widget.readOnly) return true;
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
        onTapUp: widget.readOnly
            ? null
            : (details) {
                final pos = _gridPos(details.globalPosition, art);
                if (pos != null) widget.onCellTap?.call(pos.$1, pos.$2);
              },
        onLongPressStart: widget.readOnly
            ? null
            : (details) {
                if (widget.onCellLongPress == null) return;
                final pos = _gridPos(details.globalPosition, art);
                if (pos != null) widget.onCellLongPress!(pos.$1, pos.$2);
              },
        child: MouseRegion(
          onHover: widget.readOnly
              ? null
              : (event) {
                  final pos = _gridPos(event.position, art);
                  // Mouse-move events fire continuously; only rebuild (and force a
                  // full grid repaint) when the hovered CELL actually changes.
                  if (pos?.$1 == _hoverRow && pos?.$2 == _hoverCol) return;
                  setState(() {
                    _hoverRow = pos?.$1;
                    _hoverCol = pos?.$2;
                  });
                },
          onExit: widget.readOnly
              ? null
              : (_) {
                  if (_hoverRow == null && _hoverCol == null) return;
                  setState(() {
                    _hoverRow = null;
                    _hoverCol = null;
                  });
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
      repaint: switch (layer) {
        _GridLayer.flatBase => _flatBaseRepaint,
        _GridLayer.flatOverlay => _flatOverlayRepaint,
        _GridLayer.gemBase => _gemBaseRepaint,
        _GridLayer.gemOverlay => _gemOverlayRepaint,
        _GridLayer.crossStitchBase => _crossStitchBaseRepaint,
        _GridLayer.crossStitchOverlay => _crossStitchOverlayRepaint,
        _GridLayer.beadBase => _beadBaseRepaint,
        _GridLayer.beadOverlay => _beadOverlayRepaint,
        _GridLayer.brickBase => _brickBaseRepaint,
        _GridLayer.brickOverlay => _brickOverlayRepaint,
        _GridLayer.knitBase => _knitBaseRepaint,
        _GridLayer.knitOverlay => _knitOverlayRepaint,
        _GridLayer.mosaicBase => _mosaicBaseRepaint,
        _GridLayer.mosaicOverlay => _mosaicOverlayRepaint,
        _GridLayer.glowBase => _glowBaseRepaint,
        _GridLayer.glowOverlay => _glowOverlayRepaint,
        _GridLayer.stickerBase => _stickerBaseRepaint,
        _GridLayer.stickerOverlay => _stickerOverlayRepaint,
        _GridLayer.quiltBase => _quiltBaseRepaint,
        _GridLayer.quiltOverlay => _quiltOverlayRepaint,
        _GridLayer.voxelBase => _voxelBaseRepaint,
        _GridLayer.voxelOverlay => _voxelOverlayRepaint,
      },
      art: art,
      filledGrid: widget.provider.filledGrid,
      filledColors: widget.provider.filledColors,
      selectedNumber: widget.readOnly ? -1 : widget.provider.selectedNumber,
      showNumbers: !widget.readOnly && widget.provider.showNumbers,
      highlightedNumber: widget.readOnly ? null : widget.provider.highlightedNumber,
      cellSize: widget.cellSize,
      isEraseMode: widget.readOnly ? false : widget.isEraseMode,
      brushSize: widget.brushSize,
      colorblindMode: widget.colorblindMode,
      gridFade: widget.gridFade,
      transform: widget.transform,
      fillGrow: widget.fillGrow,
      sectionShimmer: widget.sectionShimmer,
      hoverRow: widget.readOnly ? null : _hoverRow,
      hoverCol: widget.readOnly ? null : _hoverCol,
      gemStyle: FlavorConfig.current.cellStyle == CellRenderStyle.gem,
      crossStitchStyle: FlavorConfig.current.cellStyle == CellRenderStyle.crossStitch,
      beadStyle: FlavorConfig.current.cellStyle == CellRenderStyle.bead,
      brickStyle: FlavorConfig.current.cellStyle == CellRenderStyle.brick,
      knitStyle: FlavorConfig.current.cellStyle == CellRenderStyle.knit,
      mosaicStyle: FlavorConfig.current.cellStyle == CellRenderStyle.mosaic,
      glowStyle: FlavorConfig.current.cellStyle == CellRenderStyle.glow,
      stickerStyle: FlavorConfig.current.cellStyle == CellRenderStyle.sticker,
      quiltStyle: FlavorConfig.current.cellStyle == CellRenderStyle.quilt,
      voxelStyle: FlavorConfig.current.cellStyle == CellRenderStyle.voxel,
      tiltNotifier: widget.tiltNotifier,
      shaderProgram: _gemShaderProgram,
      crossStitchShaderProgram: _crossStitchShaderProgram,
      flatShaderProgram: _flatShaderProgram,
      fillVersion: widget.provider.fillVersion,
      changesSince: widget.provider.changesSince,
    );
  }

  Widget _buildCanvas(dynamic art) {
    final cellStyle = FlavorConfig.current.cellStyle;
    if (cellStyle == CellRenderStyle.flat) {
      // Flat mode paints in two isolated layers, mirroring the gem split: the
      // base (all settled cells, previews, borders, labels) repaints only on
      // fill/selection/zoom changes and when a grow animation settles, while
      // the tiny overlay (growing cells, afterglow, shimmer, hover cursor)
      // rides the 60fps fill-grow ticks. Without the split, every tick of the
      // ~700ms post-fill animation re-drew every visible cell and label.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.flatBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.flatOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.crossStitch) {
      // Cross-stitch mode: same two-layer architecture as gem.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.crossStitchBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.crossStitchOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.bead) {
      // Bead art mode: pegboard background + 3D fuse beads.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.beadBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.beadOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.brick) {
      // Brick art mode: plastic baseplate + 3D studded building bricks.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.brickBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.brickOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.knit) {
      // Knit art mode: cozy oatmeal fabric + V-loop yarn stitches.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.knitBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.knitOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.mosaic) {
      // Mosaic art mode: sandy mortar grout + glazed ceramic tiles.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.mosaicBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.mosaicOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.glow) {
      // Glow art mode: dark lite-brite pegboard + neon luminous pegs.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.glowBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.glowOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.sticker) {
      // Sticker art mode: clean notebook backing + glossy die-cut vinyl stickers.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.stickerBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.stickerOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.quilt) {
      // Quilt art mode: linen fabric backing + stitched patchwork fabric swatches.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.quiltBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.quiltOverlay),
            ),
          ),
        ],
      );
    }
    if (cellStyle == CellRenderStyle.voxel) {
      // Voxel 3D art mode: isometric cubic blocks with directional lighting.
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: _buildPainter(art, _GridLayer.voxelBase),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              willChange: false,
              painter: _buildPainter(art, _GridLayer.voxelOverlay),
            ),
          ),
        ],
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

/// Which slice of the grid a painter instance draws. Both modes split the
/// canvas into a static-ish base layer and an animated overlay so each can
/// repaint on its own triggers.
enum _GridLayer { flatBase, flatOverlay, gemBase, gemOverlay, crossStitchBase, crossStitchOverlay, beadBase, beadOverlay, brickBase, brickOverlay, knitBase, knitOverlay, mosaicBase, mosaicOverlay, glowBase, glowOverlay, stickerBase, stickerOverlay, quiltBase, quiltOverlay, voxelBase, voxelOverlay }

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

  /// When true, filled cells render as cross stitches on fabric canvas.
  final bool crossStitchStyle;

  /// When true, filled cells render as 3D cylindrical fuse beads on a pegboard.
  final bool beadStyle;

  /// When true, filled cells render as 3D plastic building bricks with top studs.
  final bool brickStyle;

  /// When true, filled cells render as cozy interlocking V-stitch woolen yarn.
  final bool knitStyle;

  /// When true, filled cells render as glazed ceramic mosaic tiles with grout lines.
  final bool mosaicStyle;

  /// When true, filled cells render as luminous neon light pegs with radial bloom.
  final bool glowStyle;

  /// When true, filled cells render as glossy vinyl die-cut sticker tiles with crisp white border.
  final bool stickerStyle;

  /// When true, filled cells render as textured patchwork fabric swatches with running stitch seams.
  final bool quiltStyle;

  /// When true, filled cells render as extruded 3D isometric voxel blocks with directional lighting.
  final bool voxelStyle;
  final ValueNotifier<Offset>? tiltNotifier;
  final ui.FragmentProgram? shaderProgram;
  final ui.FragmentProgram? crossStitchShaderProgram;
  final ui.FragmentProgram? flatShaderProgram;

  /// Monotonic counter from the provider that bumps on every fill (and on art
  /// load). Used as the cache key for the baked gem picture and the shader's
  /// grid texture so neither is regenerated while the fill is unchanged —
  /// cheaper and more reliable than rescanning all cells for a hash each frame.
  final int fillVersion;

  /// The provider's dirty-cell journal query. Lets the shader texture rebuild
  /// patch only the cells changed since its cached fillVersion instead of
  /// re-rasterizing all W×H texels on every stroke frame. Null (or a null
  /// return) falls back to the full rebuild.
  final List<(int, int)>? Function(int sinceVersion)? changesSince;

  _PixelGridPainter({
    required this.layer,
    super.repaint,
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
    this.crossStitchStyle = false,
    this.beadStyle = false,
    this.brickStyle = false,
    this.knitStyle = false,
    this.mosaicStyle = false,
    this.glowStyle = false,
    this.stickerStyle = false,
    this.quiltStyle = false,
    this.voxelStyle = false,
    this.tiltNotifier,
    this.shaderProgram,
    this.crossStitchShaderProgram,
    this.flatShaderProgram,
    this.fillVersion = 0,
    this.changesSince,
    // `repaint` is pre-merged per layer by _PixelGridState (see
    // _rebuildRepaintListenables) so painter reconstruction on every provider
    // notify doesn't allocate a fresh Listenable.merge.
  });

  /// Laid-out number labels, cached across frames and painter instances.
  /// Keyed by number, font size, and the quantized LOD fade step — without
  /// this, every visible cell allocated and laid out a TextPainter per frame.
  static final Map<int, TextPainter> _textCache = {};

  static TextPainter _numberPainter(
    int number,
    double fontSize,
    int alphaStep, {
    bool isContrast = false,
  }) {
    final textColor = isContrast ? Colors.white : const Color(0xFF555555);
    final key =
        (isContrast ? 1000000 : 0) +
        number * 10000 +
        (fontSize * 10).round() * 10 +
        alphaStep;
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
    final target =
        filledColors[number] ??
        art.colorForNumber(number) ??
        AppStyle.numberToColor(number);
    final argb = target.toARGB32();
    return _previewCache.putIfAbsent(argb * 8 + detailStep, () {
      final luminance =
          0.299 * (target.r * 255) +
          0.587 * (target.g * 255) +
          0.114 * (target.b * 255);
      final v = (150 + luminance * 0.41).round().clamp(0, 255);
      final gray = Color.fromARGB(255, v, v, v);
      // Soft dim artwork color (dulled starting point so unfilled guide colors are more muted)
      final dimColor = Color.lerp(gray, target, 0.20)!;
      // detailStep 0 = fully zoomed out: dim artwork color
      // detailStep 4 = zoomed in: tonal gray-out (no white gap)
      final t = (detailStep / 4.0).clamp(0.0, 1.0);
      return Color.lerp(dimColor, gray, t)!;
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

  // Reused across cells/frames — this runs per colorblind cell per repaint.
  static final Paint _patternPaint = Paint()
    ..color = Colors.black.withAlpha(30);

  void _drawPattern(
    Canvas canvas,
    Rect rect,
    int number,
    double cw,
    double ch,
  ) {
    final idx = (number - 1) % _patterns.length;
    final pattern = _patterns[idx];
    final patPaint = _patternPaint;
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var row = 0; row < gridHeight; row++) {
      for (var col = 0; col < gridWidth; col++) {
        final expectedNumber = art.grid[row][col] as int;
        final isRevealed =
            fillGrow == null || fillGrow!.isRevealed(row, col, nowMs);
        if (expectedNumber == 0 || (filledGrid[row][col] > 0 && isRevealed)) {
          continue;
        }
        final isSelected = expectedNumber == selectedNumber;
        final isHighlighted =
            highlightedNumber != null && expectedNumber == highlightedNumber;

        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );

        if (isSelected && !isEraseMode && selectedNumber > 0) {
          c.drawRect(
            rect,
            Paint()..color = const Color(0xFF808080),
          );
        } else if (isHighlighted && detailStep > 0) {
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

  static ui.Picture? _flatOverlayStaticPicture;
  static String _flatOverlayArtId = '';
  static int _flatOverlayFillVersion = -1;
  static int _flatOverlayDetailStep = -1;
  static int _flatOverlaySelected = -1;
  static int _flatOverlayHighlighted = -2;
  static bool _flatOverlayShowNumbers = false;
  static bool _flatOverlayIsEraseMode = false;
  static double _flatOverlayWidth = 0.0;
  static double _flatOverlayHeight = 0.0;

  static ui.Picture? _bakedFlatBasePicture;
  static String _bakedFlatArtId = '';
  static int _bakedFlatFillVersion = -1;
  static bool _bakedFlatLowDetail = false;
  static int _bakedFlatSelected = -1;
  static bool _bakedFlatIsEraseMode = false;
  static bool _bakedFlatColorblindMode = false;
  static double _bakedFlatWidth = 0.0;
  static double _bakedFlatHeight = 0.0;

  /// Records static content for flat mode — selection glow/borders, highlight
  /// tints, and number labels for every unfilled cell — into a [ui.Picture] once
  /// per (fill, selection, LOD-bucket) state. Replaying this picture per frame
  /// replaces thousands of TextPainter.paint and rect calls during pans and swipes.
  void _ensureFlatOverlayStatics(
    Size size,
    double cw,
    double ch,
    double cellGap,
    int detailStep,
    double fontSize,
  ) {
    final highlightKey = highlightedNumber ?? -1;
    if (_flatOverlayStaticPicture != null &&
        _flatOverlayArtId == art.id &&
        _flatOverlayFillVersion == fillVersion &&
        _flatOverlayDetailStep == detailStep &&
        _flatOverlaySelected == selectedNumber &&
        _flatOverlayHighlighted == highlightKey &&
        _flatOverlayShowNumbers == showNumbers &&
        _flatOverlayIsEraseMode == isEraseMode &&
        _flatOverlayWidth == size.width &&
        _flatOverlayHeight == size.height) {
      return;
    }

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);

    final highlightPaint = _highlightTintPaint;
    final selectedBorderPaint = _selectedBorderPaint
      ..color = isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF);
    final glowPaint = _glowPaint
      ..color = (isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF))
          .withAlpha(36);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var row = 0; row < gridHeight; row++) {
      for (var col = 0; col < gridWidth; col++) {
        final expectedNumber = art.grid[row][col] as int;
        if (expectedNumber <= 0) continue;

        final isRevealed =
            fillGrow == null || fillGrow!.isRevealed(row, col, nowMs);
        if (filledGrid[row][col] > 0 && isRevealed) {
          continue;
        }

        final isSelected = expectedNumber == selectedNumber;
        final isHighlighted =
            highlightedNumber != null && expectedNumber == highlightedNumber;

        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );

        if (isSelected && !isEraseMode && selectedNumber > 0) {
          c.drawRect(rect, Paint()..color = const Color(0xFF808080));
          c.drawRect(rect.deflate(1), selectedBorderPaint);
          c.drawRect(rect.deflate(1), glowPaint);
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

    _flatOverlayStaticPicture?.dispose();
    _flatOverlayStaticPicture = recorder.endRecording();
    _flatOverlayArtId = art.id as String;
    _flatOverlayFillVersion = fillVersion;
    _flatOverlayDetailStep = detailStep;
    _flatOverlaySelected = selectedNumber;
    _flatOverlayHighlighted = highlightKey;
    _flatOverlayShowNumbers = showNumbers;
    _flatOverlayIsEraseMode = isEraseMode;
    _flatOverlayWidth = size.width;
    _flatOverlayHeight = size.height;
  }

  static Float32List? _gridLinesStaging;

  /// Batched grid line renderer: replaces thousands of individual rect strokes
  /// with a single drawRawPoints lines pass across visible cells.
  void _paintGridLines(
    Canvas canvas,
    double cw,
    double ch,
    int firstRow,
    int lastRow,
    int firstCol,
    int lastCol,
    Paint borderPaint,
  ) {
    if (borderPaint.color.a == 0) return;

    final xMin = firstCol * cw;
    final xMax = (lastCol + 1) * cw;
    final yMin = firstRow * ch;
    final yMax = (lastRow + 1) * ch;

    final numH = (lastRow - firstRow + 2);
    final numV = (lastCol - firstCol + 2);
    final totalLines = numH + numV;
    final totalFloats = totalLines * 4;

    var staging = _gridLinesStaging;
    if (staging == null || staging.length < totalFloats) {
      staging = _gridLinesStaging = Float32List(totalFloats);
    }

    var idx = 0;
    // Horizontal lines
    for (var r = firstRow; r <= lastRow + 1; r++) {
      final y = r * ch;
      staging[idx++] = xMin;
      staging[idx++] = y;
      staging[idx++] = xMax;
      staging[idx++] = y;
    }
    // Vertical lines
    for (var c = firstCol; c <= lastCol + 1; c++) {
      final x = c * cw;
      staging[idx++] = x;
      staging[idx++] = yMin;
      staging[idx++] = x;
      staging[idx++] = yMax;
    }

    canvas.drawRawPoints(
      ui.PointMode.lines,
      Float32List.sublistView(staging, 0, idx),
      borderPaint,
    );
  }

  // Gem rendering tuning — kept as named constants for quick visual iteration.
  static const double _gemRingWidth =
      0.18; // stroke width as fraction of radius
  static const double _gemHighlightOffset =
      0.35; // specular dot offset from center
  static const int _gemHighlightCoreAlpha = 95;
  static const int _gemHighlightHaloAlpha = 45;

  /// Draws the static 3D body of a gem cell (drop shadow, 3D dome gradient, bevel, facet cuts).
  /// This heavy geometry is recorded into an offscreen [ui.Picture] cache.
  void _drawGemBase(
    Canvas canvas,
    Rect rect,
    Color base,
    Paint cellPaint,
    double effectiveCell,
  ) {
    final c = rect.center;
    final r = rect.shortestSide / 2;

    // 1. Zoomed out LOD (< 10.0): Fast flat rounded tile
    if (effectiveCell < 10.0) {
      cellPaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = base;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        cellPaint,
      );
      return;
    }

    const shiftX = -0.707;
    const shiftY = -0.707;

    // 2. 2.5D Contact Drop Shadow onto canvas grid
    final shadowDx = (r * 0.12).clamp(1.0, 3.5);
    final shadowDy = (r * 0.16).clamp(1.2, 4.5);
    final shadowOffset = Offset(c.dx + shadowDx, c.dy + shadowDy);
    cellPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = const Color(0x40000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: shadowOffset,
          width: rect.width,
          height: rect.height,
        ),
        const Radius.circular(3),
      ),
      cellPaint,
    );

    // 3. 3D Spherical Radial Gradient Body with Dynamic Facet Shading
    final focalOffset = Offset(
      c.dx - r * 0.35,
      c.dy - r * 0.35,
    );
    final brightBase = _lighten(base, 0.08);
    final lightShade = _lighten(base, 0.30);
    final darkShade = _darken(base, 0.28);

    cellPaint
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        focalOffset,
        r * 1.20,
        [lightShade, brightBase, darkShade],
        [0.0, 0.45, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      cellPaint,
    );
    cellPaint.shader = null;

    // Bevel outer ring: top-left glossy sheen & bottom-right depth seam
    cellPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * _gemRingWidth)
      ..color = Colors.white.withAlpha(65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      cellPaint,
    );
    cellPaint.style = PaintingStyle.fill;

    // 4. Tier 3 High Detail: Octagonal Table Cut & 8 Facet Crown Seams (Zoom >= 16.0)
    if (effectiveCell >= 16.0) {
      final facetPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.07);

      final tableRadius = r * 0.44;
      final tableCenter = Offset(
        c.dx - r * 0.06,
        c.dy - r * 0.06,
      );

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

        final p1 = Offset(
          tableCenter.dx + tableRadius * cosA,
          tableCenter.dy + tableRadius * sinA,
        );
        final p2 = Offset(c.dx + (r * 0.90) * cosA, c.dy + (r * 0.90) * sinA);

        facetPaint.color = (i < 4)
            ? Colors.white.withAlpha(70)
            : darkShade.withAlpha(70);
        canvas.drawLine(p1, p2, facetPaint);
      }

      // Flat Octagonal Table Facet Cut with crystal glass sheen
      cellPaint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withAlpha(60);
      canvas.drawPath(octPath, cellPaint);

      cellPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.9, r * 0.07)
        ..color = Colors.white.withAlpha(110);
      canvas.drawPath(octPath, cellPaint);
      cellPaint.style = PaintingStyle.fill;
    }

    // Secondary Rim Bounce Light (bottom opposite edge)
    final bounceHL = Offset(
      c.dx - r * _gemHighlightOffset * shiftX * 0.8,
      c.dy - r * _gemHighlightOffset * shiftY * 0.8,
    );
    cellPaint.color = lightShade.withAlpha(30);
    canvas.drawCircle(bounceHL, r * 0.25, cellPaint);
  }

  /// Draws the lightweight dynamic specular highlight dot & star glare flare.
  /// Shifted dynamically per frame based on [shiftX] and [shiftY] from tilt/position.
  void _drawGemHighlight(
    Canvas canvas,
    Rect rect,
    Paint cellPaint,
    double effectiveCell,
    double shiftX,
    double shiftY,
  ) {
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
      final flarePaint = _flarePaint
        ..color = Colors.white.withAlpha(120)
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

  // Reused across cells/frames — the star flare draws per filled cell at
  // high zoom on every tilt/pan frame.
  static final Paint _flarePaint = Paint();

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
      final r = (color.r * 255 + (255 - color.r * 255) * amount).round().clamp(
        0,
        255,
      );
      final g = (color.g * 255 + (255 - color.g * 255) * amount).round().clamp(
        0,
        255,
      );
      final b = (color.b * 255 + (255 - color.b * 255) * amount).round().clamp(
        0,
        255,
      );
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

    // Incremental fast path: during a stroke this runs once per frame (the
    // provider bumps fillVersion per painted cell), and re-rasterizing all
    // W×H texels each time was the dominant gem-path cost. Patch only the
    // cells changed since the cached version over the previous image instead.
    final prior = _cachedGridImage;
    if (prior != null &&
        _cachedImageArtId == art.id &&
        _cachedImageW == width &&
        _cachedImageH == height) {
      final dirty = changesSince?.call(_cachedImageFillVersion);
      if (dirty != null) {
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder);
        c.drawImage(prior, Offset.zero, paint);
        // BlendMode.src replaces the texel outright, so an erase restores the
        // half-alpha preview (or transparency) instead of blending over the
        // old fill color. Cell state is read fresh from the grid, so journal
        // duplicates and ordering don't matter.
        paint.blendMode = BlendMode.src;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final (r, col) in dirty) {
          if (r < 0 || r >= height || col < 0 || col >= width) continue;
          final expectedNumber = art.grid[r][col] as int;
          final isRevealed =
              fillGrow == null || fillGrow!.isRevealed(r, col, nowMs);
          if (filledGrid[r][col] > 0 && isRevealed) {
            paint.color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
          } else if (expectedNumber > 0) {
            paint.color = _previewColor(expectedNumber, 0).withAlpha(128);
          } else {
            paint.color = const Color(0x00000000);
          }
          c.drawRect(
            Rect.fromLTWH(col.toDouble(), r.toDouble(), 1.0, 1.0),
            paint,
          );
        }
        paint.blendMode = BlendMode.srcOver;
        final picture = recorder.endRecording();
        _cachedGridImage = picture.toImageSync(width, height);
        picture.dispose();
        prior.dispose();
        _cachedImageFillVersion = fillVersion;
        _rebuildAgeTexture(width, height);
        return;
      }
    }

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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var r = 0; r < height; r++) {
      final row = filledGrid[r];
      for (var col = 0; col < width; col++) {
        final isRevealed =
            fillGrow == null || fillGrow!.isRevealed(r, col, nowMs);
        if (row[col] > 0 && isRevealed) {
          // Match the CPU fallback: colour a filled cell by its expected
          // number so both render paths look identical.
          final expectedNumber = art.grid[r][col] as int;
          paint.color =
              filledColors[expectedNumber] ??
              AppStyle.numberToColor(expectedNumber);
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
    c.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);

    fillGrow?.forEachActive((row, col, startMs) {
      final ageMs = nowMs - startMs;
      if (ageMs < 0 || ageMs >= _fillAnimWindowMs) return;
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
    final cellGap = (gemStyle || crossStitchStyle || beadStyle || brickStyle || knitStyle || mosaicStyle || glowStyle || stickerStyle || quiltStyle || voxelStyle) ? 0.0 : 0.2 * gridLineOpacity;
    final effectiveCell = min(cw, ch) * viewerScale;
    // Scale LOD threshold by screen-space cell size rather than raw zoom:
    // for large grids (64x64+), tiny cells (< 11px) stay in fast preview mode
    // with no unreadable micro-labels until zoomed in enough to comfortably tap.
    final scaleProgress = ((effectiveCell - 11.0) / 7.0).clamp(0.0, 1.0);
    final detailStep = (scaleProgress * 4).round();
    return (cw, ch, cellGap, effectiveCell, detailStep, gridLineOpacity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (layer) {
      case _GridLayer.gemBase:
        _paintGemBase(canvas, size);
      case _GridLayer.gemOverlay:
        _paintGemOverlay(canvas, size);
      case _GridLayer.crossStitchBase:
        _paintCrossStitchBase(canvas, size);
      case _GridLayer.crossStitchOverlay:
        _paintCrossStitchOverlay(canvas, size);
      case _GridLayer.flatBase:
        _paintFlatBase(canvas, size);
      case _GridLayer.flatOverlay:
        _paintFlatOverlay(canvas, size);
      case _GridLayer.beadBase:
        _paintBeadBase(canvas, size);
      case _GridLayer.beadOverlay:
        _paintBeadOverlay(canvas, size);
      case _GridLayer.brickBase:
        _paintBrickBase(canvas, size);
      case _GridLayer.brickOverlay:
        _paintBrickOverlay(canvas, size);
      case _GridLayer.knitBase:
        _paintKnitBase(canvas, size);
      case _GridLayer.knitOverlay:
        _paintKnitOverlay(canvas, size);
      case _GridLayer.mosaicBase:
        _paintMosaicBase(canvas, size);
      case _GridLayer.mosaicOverlay:
        _paintMosaicOverlay(canvas, size);
      case _GridLayer.glowBase:
        _paintGlowBase(canvas, size);
      case _GridLayer.glowOverlay:
        _paintGlowOverlay(canvas, size);
      case _GridLayer.stickerBase:
        _paintStickerBase(canvas, size);
      case _GridLayer.stickerOverlay:
        _paintStickerOverlay(canvas, size);
      case _GridLayer.quiltBase:
        _paintQuiltBase(canvas, size);
      case _GridLayer.quiltOverlay:
        _paintQuiltOverlay(canvas, size);
      case _GridLayer.voxelBase:
        _paintVoxelBase(canvas, size);
      case _GridLayer.voxelOverlay:
        _paintVoxelOverlay(canvas, size);
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
        Paint()..color = const Color(0xFFF7F8FA),
      );

      final recPaint = Paint();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawGemBase(recorderCanvas, rect, color, recPaint, effectiveCell);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
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
        _drawGemHighlight(
          canvas,
          rect,
          cellPaint,
          effectiveCell,
          shiftX,
          shiftY,
        );
      }
    }
  }

  /// Cross-stitch art body: one fragment-shader draw on the GPU path, or the
  /// baked whole-grid picture when the shader is unavailable.
  void _paintCrossStitchBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    if (crossStitchShaderProgram != null && !colorblindMode) {
      _updateGridTextureIfNeeded();
      final gridImage = _cachedGridImage;
      final ageImage = _cachedAgeImage;
      if (gridImage != null && ageImage != null) {
        final shader = crossStitchShaderProgram!.fragmentShader();
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, gridWidth.toDouble());
        shader.setFloat(3, gridHeight.toDouble());
        final tilt = tiltNotifier?.value ?? Offset.zero;
        shader.setFloat(4, tilt.dx);
        shader.setFloat(5, tilt.dy);
        shader.setFloat(6, effectiveCell);
        shader.setFloat(
          7,
          (DateTime.now().millisecondsSinceEpoch - _ageEpochMs) / 1000.0,
        );
        shader.setFloat(8, sectionShimmer?.value ?? 1.0);
        shader.setImageSampler(0, gridImage);
        shader.setImageSampler(1, ageImage);

        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
        return;
      }
    }

    // CPU fallback: baked picture (identical strategy to gem CPU path).
    final lowDetail = detailStep == 0;
    if (_bakedBasePicture == null ||
        _bakedFillVersion != fillVersion ||
        _bakedLowDetail != lowDetail ||
        _bakedArtId != art.id ||
        _bakedWidth != size.width ||
        _bakedHeight != size.height) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);

      // Artwork background: natural Aida cloth
      recorderCanvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        Paint()..color = const Color(0xFFF7F5F0),
      );

      final recPaint = Paint();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            // CPU cross-stitch: draw an X-shaped stitch matching reference
            _drawCrossStitchCPU(recorderCanvas, rect, color, recPaint, effectiveCell);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              final borderPaint = Paint()
                ..color = const Color(0xFFE5E5E5)
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

  /// Cross-stitch overlay: cached static picture (selection tints + number
  /// labels). Mirrors the gem overlay path.
  void _paintCrossStitchOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);
  }

  /// CPU fallback renderer for a single cross-stitch cell: draws two diagonal
  /// strokes forming an "X" with dual drop shadow and core highlight sheen,
  /// matching the dev_81_cross_stitch stitch cell reference.
  void _drawCrossStitchCPU(
    Canvas canvas,
    Rect rect,
    Color base,
    Paint cellPaint,
    double effectiveCell,
  ) {
    // Zoomed out: flat tile
    if (effectiveCell < 7.0) {
      cellPaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = base;
      canvas.drawRect(rect, cellPaint);
      return;
    }

    // Stitch cell background: darker color of the thread (dark cell background box)
    final cellBg = Color.lerp(Colors.black, base, 0.48)!;
    cellPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = cellBg;
    canvas.drawRect(rect, cellPaint);

    final inset = rect.width * 0.05;
    // Corner eyelet needle puncture holes in Aida cloth
    final holePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x40000000);
    final holeRadius = (rect.width * 0.07).clamp(1.2, 3.5);
    canvas.drawCircle(Offset(rect.left + inset, rect.top + inset), holeRadius, holePaint);
    canvas.drawCircle(Offset(rect.right - inset, rect.top + inset), holeRadius, holePaint);
    canvas.drawCircle(Offset(rect.left + inset, rect.bottom - inset), holeRadius, holePaint);
    canvas.drawCircle(Offset(rect.right - inset, rect.bottom - inset), holeRadius, holePaint);

    // Diagonal 1: Top-Left to Bottom-Right (\) - top strand
    final pTL = Offset(rect.left + inset, rect.top + inset);
    final pBR = Offset(rect.right - inset, rect.bottom - inset);

    // Diagonal 2: Bottom-Left to Top-Right (/) - bottom strand
    final pBL = Offset(rect.left + inset, rect.bottom - inset);
    final pTR = Offset(rect.right - inset, rect.top + inset);

    final threadWidth = (rect.width * 0.36).clamp(2.5, 12.0);
    final sheenWidth = (threadWidth * 0.28).clamp(0.8, 3.0);
    final fiberWidth = (threadWidth * 0.18).clamp(0.6, 2.0);
    final sheenColor = _lighten(base, 0.32);
    final fiberLight = _lighten(base, 0.18);
    const shadowColor = Color(0x38000000);
    const shadowOffset = Offset(0.6, 0.9);

    final threadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = threadWidth
      ..strokeCap = StrokeCap.round
      ..shader = null;

    final sheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sheenWidth
      ..strokeCap = StrokeCap.round
      ..shader = null
      ..color = sheenColor;

    final fiberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fiberWidth
      ..strokeCap = StrokeCap.round
      ..shader = null
      ..color = fiberLight;

    // --- 1. Bottom Strand (/, BL to TR) ---
    // Shadow
    threadPaint.color = shadowColor;
    canvas.drawLine(pBL + shadowOffset, pTR + shadowOffset, threadPaint);

    // Base strand body
    threadPaint.color = base;
    canvas.drawLine(pBL, pTR, threadPaint);

    // Parallel multi-fiber striations
    final perp1 = Offset(-(pTR.dy - pBL.dy), pTR.dx - pBL.dx) / (pTR - pBL).distance * (threadWidth * 0.26);
    canvas.drawLine(pBL - perp1, pTR - perp1, fiberPaint);
    canvas.drawLine(pBL + perp1, pTR + perp1, fiberPaint);
    canvas.drawLine(pBL, pTR, sheenPaint);

    // --- 2. Crossover Contact Shadow on Bottom Strand ---
    final center = rect.center;
    final crossoverShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = threadWidth * 0.95
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x45000000);
    canvas.drawLine(Offset.lerp(pBL, center, 0.65)!, Offset.lerp(center, pTR, 0.35)!, crossoverShadow);

    // --- 3. Top Strand (\, TL to BR) - passes completely OVER bottom strand ---
    // Shadow onto background and bottom strand
    threadPaint.color = shadowColor;
    canvas.drawLine(pTL + shadowOffset, pBR + shadowOffset, threadPaint);

    // Top strand body
    threadPaint.color = base;
    canvas.drawLine(pTL, pBR, threadPaint);

    // Parallel multi-fiber striations along top strand
    final perp2 = Offset(-(pBR.dy - pTL.dy), pBR.dx - pTL.dx) / (pBR - pTL).distance * (threadWidth * 0.26);
    canvas.drawLine(pTL - perp2, pBR - perp2, fiberPaint);
    canvas.drawLine(pTL + perp2, pBR + perp2, fiberPaint);
    canvas.drawLine(pTL, pBR, sheenPaint);

    // Crossover crown highlight
    final crownHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sheenWidth * 1.3
      ..strokeCap = StrokeCap.round
      ..color = _lighten(base, 0.45);
    canvas.drawLine(Offset.lerp(pTL, pBR, 0.40)!, Offset.lerp(pTL, pBR, 0.60)!, crownHighlight);

    // --- 4. Cell Frame Border (matching reference screenshot square frame) ---
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x35000000);
    canvas.drawRect(rect, borderPaint);
  }

  // Bead-path static paints for high-speed rendering
  static final Paint _beadPegBgPaint = Paint()..color = const Color(0xFFF1F3F5);
  static final Paint _beadPegPinPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x35000000);
  static final Paint _beadShadowPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x2E000000);
  static final Paint _beadBodyPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _beadHighlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _beadShadedEdgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _beadHolePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x66000000);
  static final Paint _beadInnerLightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _drawBeadCell(Canvas canvas, Rect rect, Color base) {
    final center = rect.center;
    final w = rect.width;
    final outerRadius = w * 0.46;
    final holeRadius = (w * 0.19).clamp(1.4, outerRadius * 0.55);

    // 1. Soft ground contact drop shadow onto pegboard
    final shadowDx = (w * 0.04).clamp(0.6, 2.0);
    final shadowDy = (w * 0.07).clamp(0.9, 3.0);
    canvas.drawCircle(
      center + Offset(shadowDx, shadowDy),
      outerRadius,
      _beadShadowPaint,
    );

    // 2. Plastic cylinder 2.5D lower body depth (shaded underside)
    final depthOffset = Offset(0.0, (outerRadius * 0.12).clamp(0.8, 2.6));
    _beadBodyPaint.color = _darken(base, 0.22);
    canvas.drawCircle(center + depthOffset, outerRadius, _beadBodyPaint);

    // 3. Main plastic cylinder body
    _beadBodyPaint.color = base;
    canvas.drawCircle(center, outerRadius, _beadBodyPaint);

    // 4. Top-Left Rim Bevel Highlight (glossy plastic sheen)
    final strokeW = (w * 0.08).clamp(0.8, 3.2);
    _beadHighlightPaint
      ..strokeWidth = strokeW
      ..color = _lighten(base, 0.40);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - strokeW * 0.5),
      -2.6,
      1.9,
      false,
      _beadHighlightPaint,
    );

    // 5. Bottom-Right Rim Bevel Shadow
    final shadowW = (w * 0.07).clamp(0.7, 2.8);
    _beadShadedEdgePaint
      ..strokeWidth = shadowW
      ..color = _darken(base, 0.28);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius - shadowW * 0.5),
      0.5,
      1.9,
      false,
      _beadShadedEdgePaint,
    );

    // 6. Center Hollow Hole (deep cylindrical bore)
    canvas.drawCircle(center, holeRadius, _beadHolePaint);

    // 7. Pegboard pin visible at the bottom of the hole
    final pinRadius = (holeRadius * 0.55).clamp(0.8, 2.5);
    canvas.drawCircle(center, pinRadius, _beadPegPinPaint);

    // 8. Far inner bore wall catches light at bottom-right
    final innerStrokeW = (holeRadius * 0.35).clamp(0.6, 1.8);
    _beadInnerLightPaint
      ..strokeWidth = innerStrokeW
      ..color = _lighten(base, 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (holeRadius - 0.4).clamp(0.5, double.infinity)),
      0.4,
      1.7,
      false,
      _beadInnerLightPaint,
    );

    // 9. Near inner bore lip casts shadow at top-left
    _beadShadedEdgePaint
      ..strokeWidth = innerStrokeW
      ..color = const Color(0x90000000);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (holeRadius - 0.4).clamp(0.5, double.infinity)),
      -2.6,
      1.7,
      false,
      _beadShadedEdgePaint,
    );

    // 10. Specular curved acrylic glint along top-left shoulder
    final glintRadius = (outerRadius + holeRadius) * 0.5;
    final glintStrokeW = (w * 0.05).clamp(0.6, 1.6);
    _beadHighlightPaint
      ..strokeWidth = glintStrokeW
      ..color = Colors.white.withAlpha(190);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: glintRadius),
      -2.4,
      1.1,
      false,
      _beadHighlightPaint,
    );
  }

  void _paintBeadBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    final lowDetail = detailStep == 0;
    if (_bakedBasePicture == null ||
        _bakedFillVersion != fillVersion ||
        _bakedLowDetail != lowDetail ||
        _bakedArtId != art.id ||
        _bakedWidth != size.width ||
        _bakedHeight != size.height) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);

      // Pegboard background: clean pegboard light slate
      recorderCanvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        _beadPegBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawBeadCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              // Pegboard socket guide ring & center pin
              final socketPaint = Paint()
                ..color = const Color(0x18000000)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.4;
              recorderCanvas.drawCircle(rect.center, rect.width * 0.44, socketPaint);
              final pinRadius = (rect.width * 0.12).clamp(0.8, 2.5);
              recorderCanvas.drawCircle(rect.center, pinRadius, _beadPegPinPaint);
              final borderPaint = Paint()
                ..color = const Color(0x1A000000)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.35;
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

  void _paintBeadOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    // Growing beads during animated fills
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawBeadCell(canvas, scaledRect, color);
      });
    }

    // Section complete shimmer effect across beads
    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final gridWidth = art.gridWidth as int;
      final gridHeight = art.gridHeight as int;
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawCircle(
            Rect.fromLTWH(col * cw, row * ch, cw, ch).center,
            cw * 0.46,
            shimmerPaint,
          );
        }
      }
    }
  }

  // Brick-path static paints for high-speed rendering
  static final Paint _brickBaseplateBgPaint = Paint()..color = const Color(0xFF1E222B);
  static final Paint _brickPegPinPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x35FFFFFF);
  static final Paint _brickBodyPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _brickStudShadowPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x38000000);
  static final Paint _brickHighlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _brickShadowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _drawBrickCell(Canvas canvas, Rect rect, Color base) {
    final w = rect.width;
    final h = rect.height;
    final blockRect = rect.deflate(0.4);
    final rrect = RRect.fromRectAndRadius(blockRect, const Radius.circular(1.6));

    // 1. Flat, glossy plastic brick body
    _brickBodyPaint.color = base;
    canvas.drawRRect(rrect, _brickBodyPaint);

    // 2. Micro-edge lighting along perimeter (light from top-left)
    final rimW = (min(w, h) * 0.05).clamp(0.5, 1.2);
    _brickHighlightPaint
      ..strokeWidth = rimW
      ..color = const Color(0x45FFFFFF);
    // Top-left highlight rim
    canvas.drawLine(
      Offset(blockRect.left + 1.0, blockRect.bottom - 1.0),
      Offset(blockRect.left + 1.0, blockRect.top + 1.0),
      _brickHighlightPaint,
    );
    canvas.drawLine(
      Offset(blockRect.left + 1.0, blockRect.top + 1.0),
      Offset(blockRect.right - 1.0, blockRect.top + 1.0),
      _brickHighlightPaint,
    );

    // Bottom-right shadow rim
    _brickShadowPaint
      ..strokeWidth = rimW
      ..color = const Color(0x35000000);
    canvas.drawLine(
      Offset(blockRect.right - 1.0, blockRect.top + 1.0),
      Offset(blockRect.right - 1.0, blockRect.bottom - 1.0),
      _brickShadowPaint,
    );
    canvas.drawLine(
      Offset(blockRect.right - 1.0, blockRect.bottom - 1.0),
      Offset(blockRect.left + 1.0, blockRect.bottom - 1.0),
      _brickShadowPaint,
    );

    // 3. Raised Lego Stud in 2.5D
    final center = rect.center;
    final studRadius = (min(w, h) * 0.28).clamp(1.8, 18.0);
    final studDepth = (min(w, h) * 0.09).clamp(1.0, 3.5);

    // Stud Cast Drop Shadow onto the flat brick face
    canvas.drawCircle(
      center + Offset(studDepth * 0.5, studDepth * 0.9),
      studRadius * 1.02,
      _brickStudShadowPaint,
    );

    // Stud Cylindrical Underside (extruded side wall in shadow)
    canvas.drawCircle(
      center + Offset(0.0, studDepth * 0.45),
      studRadius,
      Paint()..color = _darken(base, 0.22),
    );

    // Stud Raised Top Face
    canvas.drawCircle(
      center - Offset(0.0, studDepth * 0.2),
      studRadius,
      Paint()..color = _lighten(base, 0.08),
    );

    // Stud Top Specular Rim (crisp plastic arc along top-left)
    final studArcW = (studRadius * 0.24).clamp(0.6, 2.0);
    _brickHighlightPaint
      ..strokeWidth = studArcW
      ..color = const Color(0x95FFFFFF);
    canvas.drawArc(
      Rect.fromCircle(
        center: center - Offset(0.0, studDepth * 0.2),
        radius: studRadius - studArcW * 0.5,
      ),
      -2.6,
      1.9,
      false,
      _brickHighlightPaint,
    );

    // Stud Bottom Occlusion Crease (arc along bottom-right)
    _brickShadowPaint
      ..strokeWidth = studArcW
      ..color = _darken(base, 0.28);
    canvas.drawArc(
      Rect.fromCircle(
        center: center - Offset(0.0, studDepth * 0.2),
        radius: studRadius - studArcW * 0.5,
      ),
      0.5,
      1.9,
      false,
      _brickShadowPaint,
    );

    // Stud Top Specular Glint (reflection point on stud surface)
    canvas.drawCircle(
      center - Offset(studRadius * 0.35, studDepth * 0.2 + studRadius * 0.35),
      (studRadius * 0.22).clamp(0.7, 1.8),
      Paint()..color = const Color(0x90FFFFFF),
    );
  }

  void _paintBrickBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    final lowDetail = detailStep == 0;
    if (_bakedBasePicture == null ||
        _bakedFillVersion != fillVersion ||
        _bakedLowDetail != lowDetail ||
        _bakedArtId != art.id ||
        _bakedWidth != size.width ||
        _bakedHeight != size.height) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);

      // Baseplate background: dark slate building baseplate
      recorderCanvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        _brickBaseplateBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawBrickCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              // Unfilled stud pin on baseplate
              final studRadius = (rect.width * 0.18).clamp(1.0, 3.5);
              recorderCanvas.drawCircle(rect.center, studRadius, _brickPegPinPaint);
              final borderPaint = Paint()
                ..color = const Color(0x28000000)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.35;
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

  void _paintBrickOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    // Growing bricks during animated fills
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawBrickCell(canvas, scaledRect, color);
      });
    }

    // Section complete shimmer effect across bricks
    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  // Knit-path static paints for high-speed rendering
  static final Paint _knitOatmealBgPaint = Paint()..color = const Color(0xFFF7F3EE);
  static final Paint _knitLoopShadowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _knitStrandPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _knitFiberSheenPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _drawKnitCell(
    Canvas canvas,
    Rect rect,
    Color base,
    double effectiveCell,
  ) {
    if (effectiveCell < 6.0) {
      canvas.drawRect(rect, Paint()..color = base);
      return;
    }

    final inset = rect.width * 0.08;
    final w = rect.width;

    // Knit cell background (slightly darker base for depth)
    final bgYarn = Color.lerp(Colors.black, base, 0.45)!;
    canvas.drawRect(rect, Paint()..color = bgYarn);

    // Points for interlocking "V" knit stitch:
    // Left strand: top-left -> bottom-center
    // Right strand: bottom-center -> top-right
    final pTL = Offset(rect.left + inset, rect.top + inset);
    final pTR = Offset(rect.right - inset, rect.top + inset);
    final pBC = Offset(rect.center.dx, rect.bottom - inset);

    final strandWidth = (w * 0.34).clamp(2.5, 11.0);
    final sheenWidth = (strandWidth * 0.28).clamp(0.8, 3.0);
    final sheenColor = _lighten(base, 0.32);
    const shadowOffset = Offset(0.5, 0.8);
    const shadowColor = Color(0x35000000);

    // 1. Left loop strand shadow + body
    _knitLoopShadowPaint
      ..strokeWidth = strandWidth
      ..color = shadowColor;
    canvas.drawLine(pTL + shadowOffset, pBC + shadowOffset, _knitLoopShadowPaint);

    _knitStrandPaint
      ..strokeWidth = strandWidth
      ..color = base;
    canvas.drawLine(pTL, pBC, _knitStrandPaint);

    // 2. Right loop strand shadow + body (passes slightly over at bottom V-point)
    canvas.drawLine(pBC + shadowOffset, pTR + shadowOffset, _knitLoopShadowPaint);
    canvas.drawLine(pBC, pTR, _knitStrandPaint);

    // 3. Yarn fiber sheen along both strands
    _knitFiberSheenPaint
      ..strokeWidth = sheenWidth
      ..color = sheenColor;
    canvas.drawLine(pTL, pBC, _knitFiberSheenPaint);
    canvas.drawLine(pBC, pTR, _knitFiberSheenPaint);

    // 4. Subtle crossover stitch knot highlight at the V point
    canvas.drawCircle(pBC, (strandWidth * 0.3).clamp(1.0, 3.0), Paint()..color = _lighten(base, 0.42));

    // 5. Delicate knit row cell seam
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = const Color(0x22000000),
    );
  }

  void _paintKnitBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    final lowDetail = detailStep == 0;
    if (_bakedBasePicture == null ||
        _bakedFillVersion != fillVersion ||
        _bakedLowDetail != lowDetail ||
        _bakedArtId != art.id ||
        _bakedWidth != size.width ||
        _bakedHeight != size.height) {
      final recorder = ui.PictureRecorder();
      final recorderCanvas = Canvas(recorder);

      // Knit fabric background: oatmeal/cream
      recorderCanvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        _knitOatmealBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawKnitCell(recorderCanvas, rect, color, effectiveCell);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              // Subtle knit guide loop
              final loopPaint = Paint()
                ..color = const Color(0x25000000)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.35;
              recorderCanvas.drawRect(rect, loopPaint);
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

  void _paintKnitOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, effectiveCell, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    // Growing stitches during animated fills
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawKnitCell(canvas, scaledRect, color, effectiveCell);
      });
    }

    // Section complete shimmer effect across knits
    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  static final Paint _mosaicGroutBgPaint = Paint()..color = const Color(0xFFD6CDBF);
  static final Paint _mosaicTilePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _mosaicBevelPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _mosaicGlazePaint = Paint()..style = PaintingStyle.fill;

  void _drawMosaicCell(Canvas canvas, Rect rect, Color base) {
    final w = min(rect.width, rect.height);
    final inset = (w * 0.08).clamp(0.6, 2.5);
    final tileRect = rect.deflate(inset);
    final r = (w * 0.16).clamp(1.0, 4.0);
    final rrect = RRect.fromRectAndRadius(tileRect, Radius.circular(r));

    _mosaicTilePaint.color = base;
    canvas.drawRRect(rrect, _mosaicTilePaint);

    final sheenRect = Rect.fromLTWH(
      tileRect.left + 0.5,
      tileRect.top + 0.5,
      tileRect.width * 0.55,
      tileRect.height * 0.45,
    );
    final sheenRRect = RRect.fromRectAndRadius(sheenRect, Radius.circular(r * 0.8));
    _mosaicGlazePaint.color = const Color(0x48FFFFFF);
    canvas.drawRRect(sheenRRect, _mosaicGlazePaint);

    final strokeW = (w * 0.07).clamp(0.6, 1.8);
    final lightPath = Path()
      ..moveTo(tileRect.left + r, tileRect.bottom - r)
      ..lineTo(tileRect.left + r, tileRect.top + r)
      ..lineTo(tileRect.right - r, tileRect.top + r);
    _mosaicBevelPaint
      ..color = const Color(0x50FFFFFF)
      ..strokeWidth = strokeW;
    canvas.drawPath(lightPath, _mosaicBevelPaint);

    final darkPath = Path()
      ..moveTo(tileRect.right - r, tileRect.top + r)
      ..lineTo(tileRect.right - r, tileRect.bottom - r)
      ..lineTo(tileRect.left + r, tileRect.bottom - r);
    _mosaicBevelPaint
      ..color = const Color(0x38000000)
      ..strokeWidth = strokeW;
    canvas.drawPath(darkPath, _mosaicBevelPaint);
  }

  void _paintMosaicBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

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
        _mosaicGroutBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawMosaicCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF808080));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              final groutGuide = Paint()
                ..color = const Color(0x30B5A895)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.5;
              recorderCanvas.drawRect(rect, groutGuide);
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

  void _paintMosaicOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawMosaicCell(canvas, scaledRect, color);
      });
    }

    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  static final Paint _glowBoardBgPaint = Paint()..color = const Color(0xFF0C0E14);
  static final Paint _glowHolePaint = Paint()..color = const Color(0xFF181C26);
  static final Paint _glowPegPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowBloomPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowCorePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowSpecPaint = Paint()..style = PaintingStyle.fill;

  void _drawGlowCell(Canvas canvas, Rect rect, Color base) {
    final center = rect.center;
    final w = min(rect.width, rect.height);
    final r = w * 0.44;

    // 1. Wide ambient diffuse aura
    _glowBloomPaint.color = base.withAlpha(45);
    canvas.drawCircle(center, r * 2.3, _glowBloomPaint);

    // 2. Vibrant mid-neon corona bloom
    _glowBloomPaint.color = base.withAlpha(115);
    canvas.drawCircle(center, r * 1.6, _glowBloomPaint);

    // 3. Peg cylinder acrylic body
    _glowPegPaint.color = base;
    canvas.drawCircle(center, r * 0.95, _glowPegPaint);

    // 4. Hot saturated luminous core (light shining directly through translucent peg)
    _glowCorePaint.color = Color.lerp(base, Colors.white, 0.65)!;
    canvas.drawCircle(center, r * 0.62, _glowCorePaint);

    // 5. White-hot center focal point
    _glowSpecPaint.color = Colors.white.withAlpha(240);
    canvas.drawCircle(center, r * 0.32, _glowSpecPaint);

    // 6. Acrylic peg surface reflection glint
    final specRadius = (r * 0.20).clamp(0.6, 2.0);
    _glowSpecPaint.color = Colors.white;
    canvas.drawCircle(
      Offset(center.dx - r * 0.35, center.dy - r * 0.35),
      specRadius,
      _glowSpecPaint,
    );
  }

  void _paintGlowBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

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
        _glowBoardBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final holeRadius = (min(cw, ch) * 0.22).clamp(1.0, 5.0);

      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawGlowCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFF353C4D));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            recorderCanvas.drawCircle(rect.center, holeRadius, _glowHolePaint);
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

  void _paintGlowOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawGlowCell(canvas, scaledRect, color);
      });
    }

    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((160 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  static final Paint _stickerSheetBgPaint = Paint()..color = const Color(0xFFF6F8FA);
  static final Paint _stickerDotPaint = Paint()..color = const Color(0xFFE2E7EE);
  static final Paint _stickerShadowPaint = Paint()..color = const Color(0x28000000);
  static final Paint _stickerWhiteBorderPaint = Paint()..color = const Color(0xFFFFFFFF);
  static final Paint _stickerFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _stickerGlossPaint = Paint()..color = const Color(0x38FFFFFF);

  void _drawStickerCell(Canvas canvas, Rect rect, Color base) {
    final w = min(rect.width, rect.height);
    final inset = (w * 0.06).clamp(0.5, 1.8);
    final stickerRect = rect.deflate(inset);
    final r = (w * 0.22).clamp(1.5, 5.5);

    // 1. Soft drop shadow (peel effect)
    final shadowOffset = (w * 0.08).clamp(0.6, 2.0);
    final shadowRect = stickerRect.shift(Offset(shadowOffset * 0.5, shadowOffset));
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(r)),
      _stickerShadowPaint,
    );

    // 2. Thick white die-cut vinyl border
    final whiteRRect = RRect.fromRectAndRadius(stickerRect, Radius.circular(r));
    canvas.drawRRect(whiteRRect, _stickerWhiteBorderPaint);

    // 3. Colored vinyl inner tile
    final borderWidth = (w * 0.12).clamp(0.8, 2.2);
    final innerRect = stickerRect.deflate(borderWidth);
    final innerR = (r - borderWidth).clamp(0.5, 5.0);
    final innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(innerR));
    _stickerFillPaint.color = base;
    canvas.drawRRect(innerRRect, _stickerFillPaint);

    // 4. Glossy vinyl sheen highlight across top-left
    final glossRect = Rect.fromLTWH(
      innerRect.left + 0.5,
      innerRect.top + 0.5,
      innerRect.width * 0.55,
      innerRect.height * 0.45,
    );
    final glossRRect = RRect.fromRectAndRadius(
      glossRect,
      Radius.circular(innerR * 0.8),
    );
    canvas.drawRRect(glossRRect, _stickerGlossPaint);
  }

  void _paintStickerBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

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
        _stickerSheetBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dotRadius = (min(cw, ch) * 0.1).clamp(0.6, 2.0);

      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawStickerCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFFE2E7EE));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              recorderCanvas.drawCircle(rect.center, dotRadius, _stickerDotPaint);
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

  void _paintStickerOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawStickerCell(canvas, scaledRect, color);
      });
    }

    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  static final Paint _quiltLinenBgPaint = Paint()..color = const Color(0xFFECE5D8);
  static final Paint _quiltPatchPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _quiltThreadPaint = Paint()
    ..color = const Color(0x66000000)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _quiltWeavePaint = Paint()
    ..color = const Color(0x18FFFFFF)
    ..style = PaintingStyle.stroke;

  void _drawQuiltCell(Canvas canvas, Rect rect, Color base) {
    final w = min(rect.width, rect.height);

    // 1. Fabric patch swatch
    _quiltPatchPaint.color = base;
    canvas.drawRect(rect, _quiltPatchPaint);

    // 2. Subtle textile weave lines
    _quiltWeavePaint.strokeWidth = 0.5;
    final step = (w * 0.25).clamp(2.0, 6.0);
    for (double x = rect.left + step; x < rect.right; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), _quiltWeavePaint);
    }

    // 3. Running thread perimeter seam
    _quiltThreadPaint.strokeWidth = (w * 0.07).clamp(0.6, 1.6);
    final inset = (w * 0.12).clamp(1.0, 3.0);
    final r = rect.deflate(inset);
    final dash = (w * 0.18).clamp(1.5, 4.0);
    final gap = (w * 0.12).clamp(1.0, 3.0);

    for (double x = r.left; x < r.right; x += dash + gap) {
      final end = min(x + dash, r.right);
      canvas.drawLine(Offset(x, r.top), Offset(end, r.top), _quiltThreadPaint);
    }
    for (double x = r.left; x < r.right; x += dash + gap) {
      final end = min(x + dash, r.right);
      canvas.drawLine(Offset(x, r.bottom), Offset(end, r.bottom), _quiltThreadPaint);
    }
    for (double y = r.top; y < r.bottom; y += dash + gap) {
      final end = min(y + dash, r.bottom);
      canvas.drawLine(Offset(r.left, y), Offset(r.left, end), _quiltThreadPaint);
    }
    for (double y = r.top; y < r.bottom; y += dash + gap) {
      final end = min(y + dash, r.bottom);
      canvas.drawLine(Offset(r.right, y), Offset(r.right, end), _quiltThreadPaint);
    }
  }

  void _paintQuiltBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

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
        _quiltLinenBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawQuiltCell(recorderCanvas, rect, color);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              recorderCanvas.drawRect(rect, Paint()..color = const Color(0xFFDCD5C5));
            } else {
              final previewColor = _previewColor(expectedNumber, detailStep);
              recorderCanvas.drawRect(rect, Paint()..color = previewColor);
            }
            if (detailStep > 0) {
              final bastingPaint = Paint()
                ..color = const Color(0x358A7F6E)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.4;
              recorderCanvas.drawRect(rect, bastingPaint);
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

  void _paintQuiltOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawQuiltCell(canvas, scaledRect, color);
      });
    }

    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  static final Paint _voxelBoardBgPaint = Paint()..color = const Color(0xFF222834);
  static final Paint _voxelTopFacetPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _voxelLeftFacetPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _voxelRightFacetPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _voxelBottomFacetPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _voxelCenterFacePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _voxelHighlightEdgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x60FFFFFF);
  static final Paint _voxelShadowEdgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x35000000);
  static final Paint _voxelMiterLightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..color = const Color(0x40FFFFFF);
  static final Paint _voxelMiterDarkPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..color = const Color(0x35000000);

  void _drawVoxelCell(Canvas canvas, Rect rect, Color base, [double grow = 1.0]) {
    final blockRect = rect.deflate(0.5);
    final bw = blockRect.width;
    final bh = blockRect.height;
    final bevel = (min(bw, bh) * 0.20 * grow.clamp(0.2, 1.0)).clamp(1.5, 6.0);
    final innerRect = blockRect.deflate(bevel);

    // 1. Top Bevel Facet (illuminated from above)
    final topFacet = Path()
      ..moveTo(blockRect.left, blockRect.top)
      ..lineTo(blockRect.right, blockRect.top)
      ..lineTo(innerRect.right, innerRect.top)
      ..lineTo(innerRect.left, innerRect.top)
      ..close();
    _voxelTopFacetPaint.color = _lighten(base, 0.28);
    canvas.drawPath(topFacet, _voxelTopFacetPaint);

    // 2. Left Bevel Facet (ambient light from left)
    final leftFacet = Path()
      ..moveTo(blockRect.left, blockRect.bottom)
      ..lineTo(blockRect.left, blockRect.top)
      ..lineTo(innerRect.left, innerRect.top)
      ..lineTo(innerRect.left, innerRect.bottom)
      ..close();
    _voxelLeftFacetPaint.color = _lighten(base, 0.12);
    canvas.drawPath(leftFacet, _voxelLeftFacetPaint);

    // 3. Right Bevel Facet (shadow facet)
    final rightFacet = Path()
      ..moveTo(blockRect.right, blockRect.top)
      ..lineTo(blockRect.right, blockRect.bottom)
      ..lineTo(innerRect.right, innerRect.bottom)
      ..lineTo(innerRect.right, innerRect.top)
      ..close();
    _voxelRightFacetPaint.color = _darken(base, 0.18);
    canvas.drawPath(rightFacet, _voxelRightFacetPaint);

    // 4. Bottom Bevel Facet (deep cast shadow)
    final bottomFacet = Path()
      ..moveTo(innerRect.left, innerRect.bottom)
      ..lineTo(innerRect.right, innerRect.bottom)
      ..lineTo(blockRect.right, blockRect.bottom)
      ..lineTo(blockRect.left, blockRect.bottom)
      ..close();
    _voxelBottomFacetPaint.color = _darken(base, 0.32);
    canvas.drawPath(bottomFacet, _voxelBottomFacetPaint);

    // 5. Raised Center Face
    _voxelCenterFacePaint.color = _lighten(base, 0.04);
    canvas.drawRect(innerRect, _voxelCenterFacePaint);

    // 6. Corner 45-degree miter seams
    canvas.drawLine(blockRect.topLeft, innerRect.topLeft, _voxelMiterLightPaint);
    canvas.drawLine(blockRect.bottomRight, innerRect.bottomRight, _voxelMiterDarkPaint);

    // 7. Specular highlight line along top and left ridges
    _voxelHighlightEdgePaint.strokeWidth = (bevel * 0.22).clamp(0.6, 1.4);
    final lightRidge = Path()
      ..moveTo(blockRect.left, blockRect.bottom)
      ..lineTo(blockRect.left, blockRect.top)
      ..lineTo(blockRect.right, blockRect.top);
    canvas.drawPath(lightRidge, _voxelHighlightEdgePaint);

    // 8. Seam shadow groove along right and bottom ridges
    _voxelShadowEdgePaint.strokeWidth = (bevel * 0.22).clamp(0.6, 1.4);
    final darkRidge = Path()
      ..moveTo(blockRect.right, blockRect.top)
      ..lineTo(blockRect.right, blockRect.bottom)
      ..lineTo(blockRect.left, blockRect.bottom);
    canvas.drawPath(darkRidge, _voxelShadowEdgePaint);

    // 9. Crisp specular highlight glint inside top-left corner
    final glintW = (innerRect.width * 0.35).clamp(1.0, 5.0);
    final glintH = (innerRect.height * 0.28).clamp(1.0, 4.0);
    final glintRect = Rect.fromLTWH(innerRect.left + 0.6, innerRect.top + 0.6, glintW, glintH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glintRect, const Radius.circular(0.8)),
      Paint()..color = const Color(0x40FFFFFF),
    );
  }

  void _paintVoxelBase(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

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
        _voxelBoardBgPaint,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (var r = 0; r < gridHeight; r++) {
        for (var c = 0; c < gridWidth; c++) {
          final isFilled =
              filledGrid[r][c] > 0 &&
              (fillGrow == null || fillGrow!.isRevealed(r, c, nowMs));
          final expectedNumber = art.grid[r][c] as int;
          final rect = Rect.fromLTWH(
            c * cw + cellGap,
            r * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );
          if (isFilled) {
            final color =
                filledColors[expectedNumber] ??
                AppStyle.numberToColor(expectedNumber);
            _drawVoxelCell(recorderCanvas, rect, color, 1.0);
            if (colorblindMode) {
              _drawPattern(recorderCanvas, rect, expectedNumber, cw, ch);
            }
          } else if (expectedNumber > 0) {
            final previewColor = _previewColor(expectedNumber, detailStep);
            recorderCanvas.drawRect(rect, Paint()..color = previewColor);

            if (!isEraseMode && selectedNumber > 0 && expectedNumber == selectedNumber) {
              // Active selected number: luminous cyan/mint selection outline
              recorderCanvas.drawRect(
                rect,
                Paint()..color = const Color(0x2500BFA5),
              );
              recorderCanvas.drawRect(
                rect.deflate(0.5),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2
                  ..color = const Color(0xFF00BFA5),
              );
            }

            if (detailStep > 0) {
              // Recessed 2.5D voxel socket groove
              final socketShadow = Path()
                ..moveTo(rect.left, rect.bottom)
                ..lineTo(rect.left, rect.top)
                ..lineTo(rect.right, rect.top);
              recorderCanvas.drawPath(
                socketShadow,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 0.6
                  ..color = const Color(0x22000000),
              );
              final socketRim = Path()
                ..moveTo(rect.right, rect.top)
                ..lineTo(rect.right, rect.bottom)
                ..lineTo(rect.left, rect.bottom);
              recorderCanvas.drawPath(
                socketRim,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 0.6
                  ..color = const Color(0x18FFFFFF),
              );
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

  void _paintVoxelOverlay(Canvas canvas, Size size) {
    final (cw, ch, cellGap, _, detailStep, _) = _layout(size);

    _ensureOverlayStatics(size, cw, ch, cellGap, detailStep);
    final statics = _overlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);

    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    if (fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return;
        if (nowMs < startMs) return;
        if (filledGrid[row][col] <= 0) return;
        final grow = fillGrow!.factor(row, col, nowMs);
        if (grow >= 1.0) return;
        final expectedNumber = art.grid[row][col] as int;
        final color = filledColors[expectedNumber] ?? AppStyle.numberToColor(expectedNumber);
        final baseRect = Rect.fromLTWH(col * cw + cellGap, row * ch + cellGap, cw - cellGap * 2, ch - cellGap * 2);
        final scaledRect = Rect.fromCenter(
          center: baseRect.center,
          width: baseRect.width * (0.2 + 0.8 * grow),
          height: baseRect.height * (0.2 + 0.8 * grow),
        );
        _drawVoxelCell(canvas, scaledRect, color, grow);
      });
    }

    if (sectionShimmer != null && sectionShimmer!.value < 1.0) {
      final t = sectionShimmer!.value;
      final band = t * 1.4 - 0.2;
      final denom = gridWidth * cw + gridHeight * ch * 0.35;
      final shimmerPaint = Paint()..style = PaintingStyle.fill;
      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          if (filledGrid[row][col] <= 0) continue;
          final q = ((col + 0.5) * cw + (row + 0.5) * ch * 0.35) / denom;
          final d = (q - band).abs();
          if (d >= 0.09) continue;
          final s = 1.0 - d / 0.09;
          shimmerPaint.color = Colors.white.withAlpha((130 * s * s).round());
          canvas.drawRect(
            Rect.fromLTWH(col * cw, row * ch, cw, ch),
            shimmerPaint,
          );
        }
      }
    }
  }

  // Flat-path paints, reused across frames (see note in _paintFlatBase).
  static final Paint _bgPaint = Paint()..color = const Color(0xFFF0F0F0);
  static final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  static final Paint _highlightTintPaint = Paint()
    ..color = const Color(0x336C63FF);
  static final Paint _selectedBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _cellPaint = Paint();
  static final Paint _glossPaint = Paint();
  static final Paint _glowPaint = Paint();
  static final Paint _shimmerPaint = Paint();
  static final Paint _cursorPaint = Paint();
  static final Paint _edgePaint = Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  /// Flat-flavor base layer: single fragment shader draw call on the GPU path,
  /// matching the architecture and locked 120 FPS performance of gem and
  /// cross-stitch flavors, with fallback to the pre-baked picture when shader
  /// is unavailable or in accessibility colorblind mode.
  void _paintFlatBase(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || art.gridWidth <= 0 || art.gridHeight <= 0) return;
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, effectiveCell, detailStep, gridLineOpacity) = _layout(size);

    if (flatShaderProgram != null && !colorblindMode) {
      _updateGridTextureIfNeeded();
      final gridImage = _cachedGridImage;
      final ageImage = _cachedAgeImage;
      if (gridImage != null && ageImage != null) {
        final shader = flatShaderProgram!.fragmentShader();
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

        final textScale = min(1.0, cw / 28);
        final xlGrid = max(gridWidth, gridHeight) >= 96;
        final fontSize = (9.0 * textScale).clamp(4.0, 12.0) - (xlGrid ? 1.0 : 0.0);

        _ensureFlatOverlayStatics(
          size,
          cw,
          ch,
          cellGap,
          detailStep,
          fontSize,
        );
        if (_flatOverlayStaticPicture != null) {
          canvas.drawPicture(_flatOverlayStaticPicture!);
        }
        return;
      }
    }

    final textScale = min(1.0, cw / 28);
    final xlGrid = max(gridWidth, gridHeight) >= 96;
    final fontSize = (9.0 * textScale).clamp(4.0, 12.0) - (xlGrid ? 1.0 : 0.0);

    final lowDetail = detailStep == 0;
    final needsRebake = _bakedFlatBasePicture == null ||
        _bakedFlatArtId != art.id ||
        _bakedFlatFillVersion != fillVersion ||
        _bakedFlatLowDetail != lowDetail ||
        _bakedFlatSelected != selectedNumber ||
        _bakedFlatIsEraseMode != isEraseMode ||
        _bakedFlatColorblindMode != colorblindMode ||
        _bakedFlatWidth != size.width ||
        _bakedFlatHeight != size.height;

    if (needsRebake) {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);

      c.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        _bgPaint,
      );

      final borderPaint = _borderPaint
        ..color = Color.fromARGB((0x22 * gridLineOpacity).round(), 0, 0, 0);

      // Reused per-cell paints; _drawGemBase toggles shader/style, so reset.
      final cellPaint = _cellPaint
        ..shader = null
        ..style = PaintingStyle.fill;
      final glossPaint = _glossPaint
        ..color = Colors.white.withAlpha((30 * gridLineOpacity).round());

      final nowMs =
          fillGrow == null ? 0 : DateTime.now().millisecondsSinceEpoch;

      for (var row = 0; row < gridHeight; row++) {
        for (var col = 0; col < gridWidth; col++) {
          final expectedNumber = art.grid[row][col] as int;
          final isFilled = filledGrid[row][col] > 0;

          final rect = Rect.fromLTWH(
            col * cw + cellGap,
            row * ch + cellGap,
            cw - cellGap * 2,
            ch - cellGap * 2,
          );

          final isRevealed =
              fillGrow == null || fillGrow!.isRevealed(row, col, nowMs);

          if (isFilled && isRevealed) {
            final grow = fillGrow == null
                ? 1.0
                : fillGrow!.factor(row, col, nowMs);
            if (grow < 1.0) {
              cellPaint.color = _previewColor(expectedNumber, detailStep);
              c.drawRect(rect, cellPaint);
              if (colorblindMode) {
                _drawPattern(c, rect, expectedNumber, cw, ch);
              }
            } else {
              cellPaint.color = filledColors[expectedNumber] ?? Colors.grey;
              c.drawRect(rect, cellPaint);
              if (colorblindMode) {
                _drawPattern(c, rect, expectedNumber, cw, ch);
              }

              c.drawRect(
                Rect.fromLTWH(
                  rect.left,
                  rect.top,
                  rect.width,
                  rect.height * 0.3,
                ),
                glossPaint,
              );
            }
          } else if (expectedNumber == 0) {
            cellPaint.color = const Color(0xFFE8E8E8);
            c.drawRect(rect, cellPaint);
          } else if (!isEraseMode &&
              selectedNumber > 0 &&
              expectedNumber == selectedNumber) {
            cellPaint.color = const Color(0xFF808080);
            c.drawRect(rect, cellPaint);
            if (colorblindMode) {
              _drawPattern(c, rect, expectedNumber, cw, ch);
            }
          } else {
            cellPaint.color = _previewColor(expectedNumber, detailStep);
            c.drawRect(rect, cellPaint);
            if (colorblindMode) {
              _drawPattern(c, rect, expectedNumber, cw, ch);
            }
          }
        }
      }

      // Draw batched grid lines across the entire canvas into the baked picture
      _paintGridLines(
        c,
        cw,
        ch,
        0,
        gridHeight - 1,
        0,
        gridWidth - 1,
        borderPaint,
      );

      _bakedFlatBasePicture?.dispose();
      _bakedFlatBasePicture = recorder.endRecording();
      _bakedFlatArtId = art.id as String;
      _bakedFlatFillVersion = fillVersion;
      _bakedFlatLowDetail = lowDetail;
      _bakedFlatSelected = selectedNumber;
      _bakedFlatIsEraseMode = isEraseMode;
      _bakedFlatColorblindMode = colorblindMode;
      _bakedFlatWidth = size.width;
      _bakedFlatHeight = size.height;
    }

    // 1. Replay cached baked flat base in 1 GPU call
    if (_bakedFlatBasePicture != null) {
      canvas.drawPicture(_bakedFlatBasePicture!);
    }

    // 2. Cached static overlay picture (selection highlight, border glow & number labels)
    _ensureFlatOverlayStatics(
      size,
      cw,
      ch,
      cellGap,
      detailStep,
      fontSize,
    );
    final statics = _flatOverlayStaticPicture;
    if (statics != null) canvas.drawPicture(statics);
  }

  /// Flat-flavor animated overlay: growing cells, afterglow, the
  /// section-complete shimmer, the hover cursor, and the outer edge stroke.
  /// Repaints at 60fps while fill animations run — but only ever draws the
  /// handful of animating cells, not the whole grid.
  void _paintFlatOverlay(Canvas canvas, Size size) {
    final gridWidth = art.gridWidth as int;
    final gridHeight = art.gridHeight as int;
    final (cw, ch, cellGap, _, detailStep, gridLineOpacity) = _layout(size);

    final clip = canvas.getLocalClipBounds();
    final firstRow = max(0, (clip.top / ch).floor());
    final lastRow = min(gridHeight - 1, (clip.bottom / ch).ceil());
    final firstCol = max(0, (clip.left / cw).floor());
    final lastCol = min(gridWidth - 1, (clip.right / cw).ceil());

    // Mirrors the base's zoomed-out fast path, where the single-pass painter
    // drew no per-cell animations, shimmer, or hover cursor.
    final lowDetail = detailStep == 0 && !colorblindMode;

    if (!lowDetail && fillGrow != null && !fillGrow!.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cellPaint = _cellPaint
        ..shader = null
        ..style = PaintingStyle.fill;
      final glossPaint = _glossPaint
        ..color = Colors.white.withAlpha((30 * gridLineOpacity).round());
      fillGrow!.forEachActive((row, col, startMs) {
        if (row < firstRow ||
            row > lastRow ||
            col < firstCol ||
            col > lastCol) {
          return;
        }
        // Scheduled in a future wave ring: do not draw overlay yet.
        if (nowMs < startMs) return;

        // Erased (or reverted) mid-animation: nothing to draw over.
        if (filledGrid[row][col] <= 0) return;
        final expectedNumber = art.grid[row][col] as int;
        final rect = Rect.fromLTWH(
          col * cw + cellGap,
          row * ch + cellGap,
          cw - cellGap * 2,
          ch - cellGap * 2,
        );
        final grow = fillGrow!.factor(row, col, nowMs);
        final crest = fillGrow!.crestGlow(row, col, nowMs);
        final age = nowMs - startMs;
        final isGrowing = age >= 0 && age < AppConstants.fillGrowMs;
        final drawRect = isGrowing
            ? Rect.fromCenter(
                center: rect.center,
                width: rect.width * (0.12 + 0.88 * grow),
                height: rect.height * (0.12 + 0.88 * grow),
              )
            : rect;
        if (isGrowing || crest > 0.0) {
          Color cellColor = filledColors[expectedNumber] ?? Colors.grey;
          if (crest > 0.0) {
            final isBomb = fillGrow!.activeWaveType == WaveFillType.bomb;
            final crestTint = isBomb ? const Color(0xFFFFD54F) : const Color(0xFFE1F5FE);
            cellColor = Color.lerp(cellColor, crestTint, crest * 0.28)!;
          }
          cellPaint.color = cellColor;
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

          if (crest > 0.0) {
            final crestRim = _glossPaint
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1.2 * crest).clamp(0.6, 2.0)
              ..color = Colors.white.withAlpha((90 * crest).round());
            canvas.drawRect(drawRect.deflate(0.5), crestRim);
            _glossPaint.style = PaintingStyle.fill;
          }
        }

        // Afterglow: a soft warm flash. During wave fills, kept minimal
        // to avoid over-glowing large groups of cells simultaneously.
        final isWave = fillGrow?.isWaveActive ?? false;
        final maxGlowAlpha = isWave ? 12 : 24;
        final glowDuration = isWave ? 0.30 : 0.36;
        final glowAge = (nowMs - startMs) / 1000.0;
        if (glowAge >= 0 && glowAge < glowDuration) {
          final glow = 1.0 - glowAge / glowDuration;
          cellPaint.color = const Color(
            0xFFFFF3D6,
          ).withAlpha((maxGlowAlpha * glow * glow).round());
          canvas.drawRect(drawRect, cellPaint);
        }
      });
    }

    if (!lowDetail) {
      // Section-complete shimmer: one skewed bright band sweeping the filled
      // cells — the CPU twin of the gem shader's effect. Runs for 600ms only,
      // over visible cells, so the extra rects never outlast the celebration.
      final shimmer = sectionShimmer?.value ?? 1.0;
      if (shimmer > 0.001 && shimmer < 0.999) {
        final band = -0.2 + 1.4 * shimmer;
        final denom = size.width + size.height * 0.35;
        final shimmerPaint = _shimmerPaint;
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
        final cursorPaint = _cursorPaint
          ..color =
              (isEraseMode ? const Color(0xFFFF6B6B) : const Color(0xFF6C63FF))
                  .withAlpha(50);
        final half = brushSize ~/ 2;
        for (var dr = -half; dr <= half; dr++) {
          for (var dc = -half; dc <= half; dc++) {
            final hr = hoverRow! + dr;
            final hc = hoverCol! + dc;
            if (hr < 0 || hr >= gridHeight || hc < 0 || hc >= gridWidth) {
              continue;
            }
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
    }

    _paintEdge(canvas, size);
  }

  void _paintEdge(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      _edgePaint,
    );
  }

  /// Releases every static cache (pictures, images, laid-out text, color
  /// memos, point buffers). Called when the grid widget leaves the tree so
  /// caches don't accumulate across artworks over a long session; they are
  /// lazily rebuilt on the next paint.
  static void releaseCaches() {
    _textCache.clear();
    _previewCache.clear();
    _darkenCache.clear();
    _lightenCache.clear();
    _overlayStaticPicture?.dispose();
    _overlayStaticPicture = null;
    _overlayArtId = '';
    _overlayFillVersion = -1;
    _flatOverlayStaticPicture?.dispose();
    _flatOverlayStaticPicture = null;
    _flatOverlayArtId = '';
    _flatOverlayFillVersion = -1;
    _bakedFlatBasePicture?.dispose();
    _bakedFlatBasePicture = null;
    _bakedFlatArtId = '';
    _bakedFlatFillVersion = -1;
    _gridLinesStaging = null;
    _bakedBasePicture?.dispose();
    _bakedBasePicture = null;
    _bakedArtId = '';
    _bakedFillVersion = -1;
    _previewLayerPicture?.dispose();
    _previewLayerPicture = null;
    _previewLayerArtId = '';
    _cachedGridImage?.dispose();
    _cachedGridImage = null;
    _cachedImageArtId = '';
    _cachedImageFillVersion = -1;
    _cachedImageW = 0;
    _cachedImageH = 0;
    _cachedAgeImage?.dispose();
    _cachedAgeImage = null;
  }

  /// Invalidates grid textures and static overlays during wave animations so the
  /// next frame patches with newly revealed wave rings.
  static void markWaveDirty() {
    _cachedImageFillVersion = -1;
    _overlayFillVersion = -1;
    _flatOverlayFillVersion = -1;
    _bakedFillVersion = -1;
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
      crossStitchStyle != old.crossStitchStyle ||
      beadStyle != old.beadStyle ||
      brickStyle != old.brickStyle ||
      knitStyle != old.knitStyle ||
      mosaicStyle != old.mosaicStyle ||
      glowStyle != old.glowStyle ||
      stickerStyle != old.stickerStyle ||
      quiltStyle != old.quiltStyle ||
      voxelStyle != old.voxelStyle ||
      crossStitchShaderProgram != old.crossStitchShaderProgram ||
      flatShaderProgram != old.flatShaderProgram ||
      // Only the flat overlay draws the hover cursor; don't force the other
      // layers to repaint on every hovered-cell change (desktop/web).
      (layer == _GridLayer.flatOverlay &&
          (hoverRow != old.hoverRow || hoverCol != old.hoverCol)) ||
      art.id != old.art.id ||
      gridFade != old.gridFade ||
      transform != old.transform ||
      fillGrow != old.fillGrow ||
      sectionShimmer != old.sectionShimmer ||
      tiltNotifier != old.tiltNotifier ||
      shaderProgram != old.shaderProgram;
}
