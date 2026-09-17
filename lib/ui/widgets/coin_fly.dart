import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Global centre of the widget owning [key], for use as a burst origin or
/// target. Null if the widget isn't laid out (e.g. scrolled away).
Offset? centerOfKey(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// Fires a short, celebratory burst of diamond icons from [origin] (defaults to
/// screen centre). Without [target] they fan outward, drift up, and fade; with
/// [target] each coin arcs from the origin to that point (the diamond counter)
/// and [onArrive] fires as the flight lands — pulse the counter there. Purely
/// visual juice for "you earned diamonds" moments — overlay-based, so it floats
/// above any screen and cleans itself up when the animation ends.
void showCoinBurst(
  BuildContext context, {
  Offset? origin,
  Offset? target,
  int count = 12,
  VoidCallback? onArrive,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final size = MediaQuery.of(context).size;
  final start = origin ?? Offset(size.width / 2, size.height / 2);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CoinBurst(
      origin: start,
      target: target,
      count: count,
      onArrive: onArrive,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _CoinBurst extends StatefulWidget {
  final Offset origin;
  final Offset? target;
  final int count;
  final VoidCallback? onArrive;
  final VoidCallback onDone;

  const _CoinBurst({
    required this.origin,
    this.target,
    required this.count,
    this.onArrive,
    required this.onDone,
  });

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<_CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Coin> _coins;
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _coins = List.generate(widget.count, (i) {
      // Fan upward: angles biased toward the top half of the circle.
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.1;
      final distance = 80 + rnd.nextDouble() * 120;
      return _Coin(
        angle: angle,
        distance: distance,
        size: 16 + rnd.nextDouble() * 14,
        delay: rnd.nextDouble() * 0.2,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.target == null ? 950 : 1100),
    )..forward().whenComplete(widget.onDone);
    if (widget.target != null && widget.onArrive != null) {
      // Pulse the counter as the leading coins land, not after the tail.
      _ctrl.addListener(() {
        if (!_arrived && _ctrl.value >= 0.8) {
          _arrived = true;
          widget.onArrive!();
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: _coins.map((c) {
              final t = ((_ctrl.value - c.delay) / (1 - c.delay)).clamp(
                0.0,
                1.0,
              );
              final target = widget.target;
              if (target == null) {
                final eased = Curves.easeOut.transform(t);
                final dx = math.cos(c.angle) * c.distance * eased;
                // Extra upward drift + slight gravity at the tail.
                final dy = math.sin(c.angle) * c.distance * eased + 30 * t * t;
                return _place(
                  widget.origin.dx + dx,
                  widget.origin.dy + dy,
                  c.size,
                  opacity: (1 - t).clamp(0.0, 1.0),
                  rotation: t * 3,
                );
              }
              // Targeted flight: a quadratic arc through the coin's fan point,
              // so the burst still blooms before converging on the counter.
              final eased = Curves.easeInOut.transform(t);
              final control = Offset(
                widget.origin.dx + math.cos(c.angle) * c.distance,
                widget.origin.dy + math.sin(c.angle) * c.distance,
              );
              final u = 1 - eased;
              final pos = widget.origin * (u * u) +
                  control * (2 * u * eased) +
                  target * (eased * eased);
              return _place(
                pos.dx,
                pos.dy,
                // Shrink slightly on approach, as if absorbed by the counter.
                c.size * (1 - 0.4 * eased),
                opacity: t > 0.92 ? ((1 - t) / 0.08).clamp(0.0, 1.0) : 1.0,
                rotation: t * 2,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _place(
    double cx,
    double cy,
    double size, {
    required double opacity,
    required double rotation,
  }) {
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Icon(
            Icons.diamond_rounded,
            size: size,
            color: const Color(0xFFFF9D2E),
          ),
        ),
      ),
    );
  }
}

class _Coin {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  const _Coin({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}
