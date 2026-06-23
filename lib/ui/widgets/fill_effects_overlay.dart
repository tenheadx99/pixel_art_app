import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

/// The kinds of joyful flourish spawned when a cell is colored.
enum _EffectKind { pop, ripple, splash, sparkle, combo }

class _FillEffect {
  final _EffectKind kind;
  final int row;
  final int col;
  final Color color;
  final int startMs;
  final int sparkleCount;
  final double seed;
  final int combo;

  _FillEffect({
    required this.kind,
    required this.row,
    required this.col,
    required this.color,
    required this.startMs,
    this.sparkleCount = 0,
    this.seed = 0,
    this.combo = 0,
  });
}

/// A transient effect layer drawn ABOVE the pixel grid. It keeps the heavy
/// grid painter untouched: short-lived pop / ripple / splash / sparkle / combo
/// effects are positioned in screen space from the shared [transformController]
/// so they stay glued to their cell during pan/zoom. Drive it imperatively via
/// a [GlobalKey] of [FillEffectsOverlayState].
class FillEffectsOverlay extends StatefulWidget {
  final TransformationController transformController;
  final double cellSize;
  final Size viewerSize;
  final int gridWidth;
  final int gridHeight;

  const FillEffectsOverlay({
    super.key,
    required this.transformController,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
  });

  @override
  State<FillEffectsOverlay> createState() => FillEffectsOverlayState();
}

class FillEffectsOverlayState extends State<FillEffectsOverlay>
    with SingleTickerProviderStateMixin {
  final List<_FillEffect> _effects = [];
  late final AnimationController _ticker;
  final math.Random _rnd = math.Random();
  int _lastFullSpawnMs = 0;

  static const int _lifetime = AppConstants.fillEffectLifetimeMs;
  static const int _maxConcurrent = AppConstants.fillEffectMaxConcurrent;

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    final now = _nowMs;
    _effects.removeWhere((e) => now - e.startMs >= _lifetime);
    if (_effects.isEmpty && _ticker.isAnimating) _ticker.stop();
  }

  void _ensureTicking() {
    if (!_ticker.isAnimating) _ticker.repeat();
  }

  void _add(_FillEffect e) {
    // Hard cap: drop the oldest effect so a fast swipe can't pile up unbounded.
    if (_effects.length >= _maxConcurrent) _effects.removeAt(0);
    _effects.add(e);
    _ensureTicking();
  }

  /// Spawns a fill flourish at [row]/[col]. Taps ([full] = true) get the rich
  /// set (pop + ripple + splash + sparkle). Mid-stroke fills ([full] = false)
  /// are rate-limited as a WHOLE — at most one light pop+sparkle per throttle
  /// window — so a fast swipe spawns a trail, not an effect per cell.
  void spawn(int row, int col, Color color, {bool full = true, int combo = 0}) {
    final now = _nowMs;

    if (!full) {
      if (now - _lastFullSpawnMs < AppConstants.fillEffectStrokeThrottleMs) {
        return; // skip entirely — keeps swipes cheap (no blur, no pile-up)
      }
      _lastFullSpawnMs = now;
      _add(_FillEffect(
        kind: _EffectKind.pop,
        row: row,
        col: col,
        color: color,
        startMs: now,
      ));
      _add(_FillEffect(
        kind: _EffectKind.sparkle,
        row: row,
        col: col,
        color: color,
        startMs: now,
        sparkleCount: 3,
        seed: _rnd.nextDouble() * math.pi * 2,
      ));
      return;
    }

    _lastFullSpawnMs = now;
    _add(_FillEffect(
      kind: _EffectKind.pop,
      row: row,
      col: col,
      color: color,
      startMs: now,
    ));
    _add(_FillEffect(
      kind: _EffectKind.ripple,
      row: row,
      col: col,
      color: color,
      startMs: now,
    ));
    _add(_FillEffect(
      kind: _EffectKind.splash,
      row: row,
      col: col,
      color: color,
      startMs: now,
    ));
    final sparkles = (3 + combo ~/ 5).clamp(3, 6);
    _add(_FillEffect(
      kind: _EffectKind.sparkle,
      row: row,
      col: col,
      color: color,
      startMs: now,
      sparkleCount: sparkles,
      seed: _rnd.nextDouble() * math.pi * 2,
    ));
  }

  /// Floating "Combo xN!" callout near a cell.
  void spawnComboText(int row, int col, int combo) {
    _add(_FillEffect(
      kind: _EffectKind.combo,
      row: row,
      col: col,
      color: const Color(0xFFFFB300),
      startMs: _nowMs,
      combo: combo,
    ));
  }

  /// A larger celebratory sparkle ring, e.g. when a whole color is finished.
  void spawnBurst(int row, int col, Color color) {
    _add(_FillEffect(
      kind: _EffectKind.sparkle,
      row: row,
      col: col,
      color: color,
      startMs: _nowMs,
      sparkleCount: 10,
      seed: _rnd.nextDouble() * math.pi * 2,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary is critical: this layer repaints every frame while
    // effects animate; without its own layer that 60fps repaint would also
    // re-run the sibling BackdropFilter glass bars and stutter the fill.
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FillEffectsPainter(
            effects: _effects,
            transform: widget.transformController,
            cellSize: widget.cellSize,
            viewerSize: widget.viewerSize,
            gridWidth: widget.gridWidth,
            gridHeight: widget.gridHeight,
            lifetime: _lifetime,
            repaint: Listenable.merge([_ticker, widget.transformController]),
          ),
        ),
      ),
    );
  }
}

class _FillEffectsPainter extends CustomPainter {
  final List<_FillEffect> effects;
  final TransformationController transform;
  final double cellSize;
  final Size viewerSize;
  final int gridWidth;
  final int gridHeight;
  final int lifetime;

  _FillEffectsPainter({
    required this.effects,
    required this.transform,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.lifetime,
    required Listenable repaint,
  }) : super(repaint: repaint);

  Offset _cellCenterScene(int row, int col) {
    final gridLeft = (viewerSize.width - gridWidth * cellSize) / 2;
    final gridTop = (viewerSize.height - gridHeight * cellSize) / 2;
    return Offset(
      gridLeft + (col + 0.5) * cellSize,
      gridTop + (row + 0.5) * cellSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (effects.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final matrix = transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final cellPx = cellSize * scale;
    final paint = Paint();

    // Iterate over a snapshot length to tolerate concurrent pruning.
    for (var i = 0; i < effects.length; i++) {
      final e = effects[i];
      final t = ((now - e.startMs) / lifetime).clamp(0.0, 1.0);
      if (t >= 1.0) continue;
      final center = MatrixUtils.transformPoint(
        matrix,
        _cellCenterScene(e.row, e.col),
      );
      switch (e.kind) {
        case _EffectKind.pop:
          _paintPop(canvas, paint, center, cellPx, t, e.color);
          break;
        case _EffectKind.ripple:
          _paintRipple(canvas, paint, center, cellPx, t, e.color);
          break;
        case _EffectKind.splash:
          _paintSplash(canvas, paint, center, cellPx, t, e.color);
          break;
        case _EffectKind.sparkle:
          _paintSparkle(canvas, paint, center, cellPx, t, e);
          break;
        case _EffectKind.combo:
          _paintCombo(canvas, center, cellPx, t, e.combo);
          break;
      }
    }
  }

  void _paintPop(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    Color color,
  ) {
    // Overshoot then settle; a quick tinted "stamp" that fades out.
    final s = Curves.elasticOut.transform(t);
    final scale = 0.6 + 0.4 * s;
    final side = cellPx * scale;
    final alpha = ((1 - t) * 0.55).clamp(0.0, 1.0);
    paint
      ..style = PaintingStyle.fill
      ..color = Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: alpha);
    final rect = Rect.fromCenter(center: c, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cellPx * 0.18)),
      paint,
    );
  }

  void _paintRipple(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    Color color,
  ) {
    final radius = cellPx * (0.5 + t * 1.4);
    final width = (cellPx * 0.14 * (1 - t)).clamp(0.5, 6.0);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: (1 - t) * 0.7);
    canvas.drawCircle(c, radius, paint);
  }

  void _paintSplash(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    Color color,
  ) {
    final radius = cellPx * (0.4 + t * 0.8);
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: (1 - t) * 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellPx * 0.3);
    canvas.drawCircle(c, radius, paint);
    paint.maskFilter = null;
  }

  void _paintSparkle(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    _FillEffect e,
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0));
    final dist = cellPx * (0.5 + t * 1.3);
    final pSize = cellPx * 0.2 * (1 - t);
    if (pSize <= 0.2) return;
    for (var i = 0; i < e.sparkleCount; i++) {
      // Golden-angle spread keeps the particles visually even.
      final angle = e.seed + i * 2.399963;
      final pos = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      _drawDiamond(canvas, paint, pos, pSize);
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.6, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.6, c.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintCombo(Canvas canvas, Offset c, double cellPx, double t, int combo) {
    final rise = t * (cellPx * 1.5 + 24);
    final scale = (0.6 + Curves.easeOutBack.transform(t.clamp(0.0, 1.0)) * 0.4)
        .clamp(0.6, 1.0);
    final alpha = (1 - t).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'Combo x$combo!',
        style: TextStyle(
          fontSize: 18 * scale,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFFB300).withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: alpha * 0.4),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - rise - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FillEffectsPainter oldDelegate) => true;
}
