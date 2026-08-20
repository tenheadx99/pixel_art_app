import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../config/flavor.dart';

/// The kinds of joyful flourish spawned when a cell is colored.
enum _EffectKind { pop, ripple, splash, sparkle, combo, wrong, bombExplosion, bombEmber }

class _FillEffect {
  final _EffectKind kind;
  final int row;
  final int col;
  final Color color;
  final int startMs;
  final int sparkleCount;
  final double seed;
  final int combo;
  final double velocityX;
  final double velocityY;

  _FillEffect({
    required this.kind,
    required this.row,
    required this.col,
    required this.color,
    required this.startMs,
    this.sparkleCount = 0,
    this.seed = 0,
    this.combo = 0,
    this.velocityX = 0.0,
    this.velocityY = 0.0,
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
  final ValueNotifier<Offset>? tiltNotifier;
  final String particleStyle;

  const FillEffectsOverlay({
    super.key,
    required this.transformController,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    this.tiltNotifier,
    this.particleStyle = 'sparkles',
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
  void spawn(
    int row,
    int col,
    Color color, {
    bool full = true,
    int combo = 0,
    bool pop = true,
  }) {
    final now = _nowMs;

    if (!full) {
      if (now - _lastFullSpawnMs < AppConstants.fillEffectStrokeThrottleMs) {
        return; // skip entirely — keeps swipes cheap (no blur, no pile-up)
      }
      _lastFullSpawnMs = now;
      if (pop) {
        _add(_FillEffect(
          kind: _EffectKind.pop,
          row: row,
          col: col,
          color: color,
          startMs: now,
        ));
      }
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
    if (pop) {
      _add(_FillEffect(
        kind: _EffectKind.pop,
        row: row,
        col: col,
        color: color,
        startMs: now,
      ));
    }
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

  /// A gentle "not this one" head-shake on a wrong-number tap: the cell
  /// wiggles under a soft red tint, clearly distinct from the joyful effects.
  void spawnWrong(int row, int col) {
    _add(_FillEffect(
      kind: _EffectKind.wrong,
      row: row,
      col: col,
      color: const Color(0xFFFF5252),
      startMs: _nowMs,
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

  /// Spawns a high-impact bomb explosion animation with shockwave rings,
  /// fiery flash cores, and exploding particle embers across the 7x7 area.
  void spawnBombExplosion(int row, int col, Color color) {
    final now = _nowMs;

    // 1. Shockwave & Central Flash
    _add(_FillEffect(
      kind: _EffectKind.bombExplosion,
      row: row,
      col: col,
      color: color,
      startMs: now,
    ));

    // 2. High-density exploding embers (16 flying particles)
    for (var i = 0; i < 16; i++) {
      final angle = _rnd.nextDouble() * math.pi * 2;
      final speed = 2.5 + _rnd.nextDouble() * 3.5;
      final emberColor = i % 3 == 0
          ? const Color(0xFFFFD700)
          : (i % 3 == 1 ? const Color(0xFFFF4500) : const Color(0xFFFF8C00));

      _add(_FillEffect(
        kind: _EffectKind.bombEmber,
        row: row,
        col: col,
        color: emberColor,
        startMs: now,
        seed: _rnd.nextDouble() * math.pi * 2,
        velocityX: math.cos(angle) * speed,
        velocityY: math.sin(angle) * speed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary is critical: this layer repaints every frame while
    // effects animate; without its own layer that 60fps repaint would also
    // re-run the sibling BackdropFilter glass bars and stutter the fill.
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          size: Size.infinite,
          painter: _FillEffectsPainter(
            effects: _effects,
            transform: widget.transformController,
            cellSize: widget.cellSize,
            viewerSize: widget.viewerSize,
            gridWidth: widget.gridWidth,
            gridHeight: widget.gridHeight,
            lifetime: _lifetime,
            particleStyle: widget.particleStyle,
            tiltNotifier: widget.tiltNotifier,
            repaint: Listenable.merge([_ticker, widget.transformController, widget.tiltNotifier]),
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
  final String particleStyle;
  final ValueNotifier<Offset>? tiltNotifier;

  _FillEffectsPainter({
    required this.effects,
    required this.transform,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.lifetime,
    this.particleStyle = 'sparkles',
    this.tiltNotifier,
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
        case _EffectKind.wrong:
          _paintWrong(canvas, paint, center, cellPx, t, e.color);
          break;
        case _EffectKind.bombExplosion:
          _paintBombExplosion(canvas, paint, center, cellPx, t, e.color);
          break;
        case _EffectKind.bombEmber:
          _paintBombEmber(canvas, paint, center, cellPx, t, e);
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
    // A crisp, punchy bounce-in "stamp": completes in the first ~45% of the
    // effect's life (snappy), overshoots past the cell edges so the motion is
    // visible against neighbours, then settles to the exact cell size.
    final pt = (t / 0.45).clamp(0.0, 1.0);
    final s = Curves.elasticOut.transform(pt); // 0 -> 1 with overshoot
    final scale = 0.7 + 0.55 * s; // grows past 1.0, springs back to ~1.0
    final side = cellPx * scale;
    final radius = Radius.circular(cellPx * 0.16);
    // Real cell color, opaque while popping then a quick fade at the tail.
    final fade = pt < 0.75 ? 1.0 : (1 - (pt - 0.75) / 0.25);
    final rect = Rect.fromCenter(center: c, width: side, height: side);
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: (fade * 0.9).clamp(0.0, 1.0));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    // White sheen flash on impact, gone within the first ~90ms-equivalent.
    final sheen = (1 - pt / 0.35).clamp(0.0, 1.0);
    if (sheen > 0) {
      paint.color = Colors.white.withValues(alpha: sheen * 0.55);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
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
    final isGem = FlavorConfig.current.cellStyle == CellRenderStyle.gem;
    final tilt = tiltNotifier?.value ?? Offset.zero;

    final driftX = isGem ? -tilt.dx * cellPx * 2.2 * t * t : 0.0;
    final driftY = isGem ? tilt.dy * cellPx * 2.2 * t * t : 0.0;

    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final dist = cellPx * (0.4 + Curves.easeOutCubic.transform(t) * 1.6);
    final pSize = cellPx * 0.24 * (1.0 - t * 0.8);
    if (pSize <= 0.2) return;

    for (var i = 0; i < e.sparkleCount; i++) {
      final angle = e.seed + i * 2.399963 + (particleStyle == 'hearts' ? 0.0 : t * 1.5);
      
      double px = c.dx + math.cos(angle) * dist + driftX;
      double py = c.dy + math.sin(angle) * dist + driftY;
      if (particleStyle == 'hearts') {
        px += math.sin(t * 8.0 + i) * cellPx * 0.3;
        py -= t * cellPx * 1.8;
      }

      final pos = Offset(px, py);
      final rotation = (e.seed * 5.0 + t * 5.0 * math.pi + i * 0.8);
      
      final Color pColor;
      if (particleStyle == 'neon') {
        const neonColors = [Color(0xFF00E5FF), Color(0xFFFF007F), Color(0xFF00FF66), Color(0xFFFFE500)];
        pColor = neonColors[i % neonColors.length];
      } else if (particleStyle == 'hearts') {
        const heartColors = [Color(0xFFFF2A6D), Color(0xFFFF5252), Color(0xFFFF758C), Color(0xFFFFB3C1)];
        pColor = heartColors[i % heartColors.length];
      } else if (particleStyle == 'stars') {
        const starColors = [Color(0xFFFFD700), Color(0xFFFFE08A), Color(0xFFFFF5CC), Colors.white];
        pColor = starColors[i % starColors.length];
      } else {
        pColor = i % 2 == 0 ? e.color : const Color(0xFFFFD700);
      }

      _drawParticle(canvas, paint, pos, pSize, particleStyle, pColor, alpha, rotation);
    }
  }

  void _drawParticle(
    Canvas canvas,
    Paint paint,
    Offset c,
    double r,
    String style,
    Color color,
    double alpha,
    double rotation,
  ) {
    final int alphaByte = (alpha * 255).round().clamp(0, 255);
    final int glowAlphaByte = (alpha * 140).round().clamp(0, 255);

    // 1. Soft Radial Glow Halo
    paint
      ..style = PaintingStyle.fill
      ..color = color.withAlpha(glowAlphaByte)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8);
    canvas.drawCircle(c, r * 1.1, paint);
    paint.maskFilter = null;

    // 2. Primary Outer Particle Shape
    paint
      ..style = PaintingStyle.fill
      ..color = color.withAlpha(alphaByte);

    switch (style) {
      case 'stars':
        _drawStar(canvas, paint, c, r * 1.1, rotation);
        break;
      case 'neon':
        _drawNeonRing(canvas, paint, c, r, alphaByte);
        break;
      case 'hearts':
        _drawHeart(canvas, paint, c, r * 1.2);
        break;
      case 'sparkles':
      default:
        _drawDiamond(canvas, paint, c, r, rotation);
        break;
    }

    // 3. Bright White Center Core
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withAlpha((alpha * 220).round().clamp(0, 255));
    canvas.drawCircle(c, r * 0.35, paint);
  }

  void _drawStar(Canvas canvas, Paint paint, Offset c, double r, double rotation) {
    final path = Path();
    const points = 5;
    final innerR = r * 0.4;
    for (int i = 0; i < points * 2; i++) {
      final rad = rotation + (i * math.pi / points);
      final radius = (i % 2 == 0) ? r : innerR;
      final x = c.dx + math.cos(rad) * radius;
      final y = c.dy + math.sin(rad) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawNeonRing(Canvas canvas, Paint paint, Offset c, double r, int alphaByte) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = r * 0.35;
    canvas.drawCircle(c, r, paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawHeart(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path();
    final width = r * 1.3;
    final height = r * 1.3;
    path.moveTo(c.dx, c.dy + height * 0.25);
    path.cubicTo(
      c.dx - width * 0.5, c.dy - height * 0.5,
      c.dx - width, c.dy + height * 0.25,
      c.dx, c.dy + height * 0.75,
    );
    path.cubicTo(
      c.dx + width, c.dy + height * 0.25,
      c.dx + width * 0.5, c.dy - height * 0.5,
      c.dx, c.dy + height * 0.25,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset c, double r, [double rotation = 0.0]) {
    if (rotation == 0.0) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.6, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.6, c.dy)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      final path = Path();
      final cosA = math.cos(rotation);
      final sinA = math.sin(rotation);
      
      final x1 = c.dx - sinA * (-r);
      final y1 = c.dy + cosA * (-r);
      final x2 = c.dx + cosA * (r * 0.6);
      final y2 = c.dy + sinA * (r * 0.6);
      final x3 = c.dx - sinA * r;
      final y3 = c.dy + cosA * r;
      final x4 = c.dx + cosA * (-r * 0.6);
      final y4 = c.dy + sinA * (-r * 0.6);

      path.moveTo(x1, y1);
      path.lineTo(x2, y2);
      path.lineTo(x3, y3);
      path.lineTo(x4, y4);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  /// Horizontal head-shake: three quick wiggles that damp out, over a soft
  /// red-tinted cell with a matching border. Ends within the first ~70% of
  /// the effect lifetime so it reads as a snappy "nope", not a lingering error.
  void _paintWrong(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    Color color,
  ) {
    final wt = (t / 0.7).clamp(0.0, 1.0);
    final shake = math.sin(wt * math.pi * 6) * cellPx * 0.14 * (1 - wt);
    final fade = (1 - wt).clamp(0.0, 1.0);
    final rect = Rect.fromCenter(
      center: Offset(c.dx + shake, c.dy),
      width: cellPx,
      height: cellPx,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(cellPx * 0.16),
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cellPx * 0.08).clamp(1.5, 3.5)
      ..color = color.withValues(alpha: fade * 0.9);
    canvas.drawRRect(rrect, paint);
    paint.style = PaintingStyle.fill;
  }

  // Laid-out combo callouts cached per combo count — building and laying out
  // a TextPainter every animation frame was avoidable churn. The per-frame
  // scale/fade are applied with canvas transforms + a saveLayer alpha, which
  // reproduces the original scaled-font + faded-color rendering (text at
  // alpha, shadow at 0.4 × alpha).
  static final Map<int, TextPainter> _comboTextCache = {};

  void _paintCombo(Canvas canvas, Offset c, double cellPx, double t, int combo) {
    final rise = t * (cellPx * 1.5 + 24);
    final scale = (0.6 + Curves.easeOutBack.transform(t.clamp(0.0, 1.0)) * 0.4)
        .clamp(0.6, 1.0);
    final alpha = (1 - t).clamp(0.0, 1.0);
    final tp = _comboTextCache.putIfAbsent(combo, () {
      return TextPainter(
        text: TextSpan(
          text: 'Combo x$combo!',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFFB300),
            shadows: [
              Shadow(color: Color(0x66000000), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    final center = Offset(c.dx, c.dy - rise);
    final bounds = Rect.fromCenter(
      center: center,
      width: tp.width * scale + 16,
      height: tp.height * scale + 16,
    );
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _paintBombExplosion(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    Color color,
  ) {
    // 7x7 radius in pixels is cellPx * 3.8
    final maxRadius = cellPx * 3.8;

    // A. Expanding Fiery Core Flash
    final flashProgress = (t / 0.5).clamp(0.0, 1.0);
    final flashScale = Curves.easeOutCubic.transform(flashProgress);
    final flashRadius = maxRadius * 0.75 * flashScale;
    final flashAlpha = (1.0 - t).clamp(0.0, 1.0);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF5252).withValues(alpha: flashAlpha * 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellPx * 0.5);
    canvas.drawCircle(c, flashRadius, paint);

    paint
      ..color = const Color(0xFFFFD700).withValues(alpha: flashAlpha * 0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellPx * 0.2);
    canvas.drawCircle(c, flashRadius * 0.5, paint);
    paint.maskFilter = null;

    // B. Primary Expanding Outer Shockwave Ring
    final shockRadius = maxRadius * Curves.decelerate.transform(t);
    final shockAlpha = (1.0 - t).clamp(0.0, 1.0);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cellPx * 0.35 * (1.0 - t)).clamp(1.5, 8.0)
      ..color = const Color(0xFFFF4500).withValues(alpha: shockAlpha * 0.85);
    canvas.drawCircle(c, shockRadius, paint);

    // C. Inner Secondary Golden Ring
    final innerRadius = maxRadius * 0.65 * Curves.easeOutQuad.transform(t);
    paint
      ..strokeWidth = (cellPx * 0.2 * (1.0 - t)).clamp(1.0, 4.0)
      ..color = const Color(0xFFFFD700).withValues(alpha: shockAlpha * 0.9);
    canvas.drawCircle(c, innerRadius, paint);
  }

  void _paintBombEmber(
    Canvas canvas,
    Paint paint,
    Offset c,
    double cellPx,
    double t,
    _FillEffect e,
  ) {
    // Ember position travels outward along velocity vector
    final dist = cellPx * (0.8 + t * 3.5);
    final offset = Offset(
      c.dx + e.velocityX * dist * 0.4,
      c.dy + e.velocityY * dist * 0.4,
    );

    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final size = cellPx * 0.35 * (1.0 - t * 0.7);
    if (size <= 0.3) return;

    paint
      ..style = PaintingStyle.fill
      ..color = e.color.withValues(alpha: alpha);

    final rotation = e.seed + t * math.pi * 4;
    _drawDiamond(canvas, paint, offset, size, rotation);
  }

  @override
  bool shouldRepaint(covariant _FillEffectsPainter oldDelegate) => true;
}
