import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../config/flavor.dart';

/// The kinds of joyful flourish spawned when a cell is colored.
enum _EffectKind { pop, ripple, splash, sparkle, combo, wrong }

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
  final ValueNotifier<Offset>? tiltNotifier;

  const FillEffectsOverlay({
    super.key,
    required this.transformController,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    this.tiltNotifier,
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
  final ValueNotifier<Offset>? tiltNotifier;

  _FillEffectsPainter({
    required this.effects,
    required this.transform,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.lifetime,
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
    
    // Sparkles drift under gravity/tilt. The drift increases quadratically over time.
    final driftX = isGem ? -tilt.dx * cellPx * 2.2 * t * t : 0.0;
    final driftY = isGem ? tilt.dy * cellPx * 2.2 * t * t : 0.0;

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: (1 - t).clamp(0.0, 1.0));
    final dist = cellPx * (0.5 + t * 1.3);
    final pSize = cellPx * 0.2 * (1 - t);
    if (pSize <= 0.2) return;
    for (var i = 0; i < e.sparkleCount; i++) {
      // Golden-angle spread keeps the particles visually even.
      final angle = e.seed + i * 2.399963;
      final pos = c + Offset(
        math.cos(angle) * dist + driftX,
        math.sin(angle) * dist + driftY,
      );
      final rotation = isGem ? (e.seed * 5.0 + t * 4.0 * math.pi + i * 0.5) : 0.0;
      _drawDiamond(canvas, paint, pos, pSize, rotation);
    }
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
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: fade * 0.35);
    canvas.drawRRect(rrect, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cellPx * 0.08).clamp(1.0, 3.0)
      ..color = color.withValues(alpha: fade * 0.9);
    canvas.drawRRect(rrect, paint);
    paint.style = PaintingStyle.fill;
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
