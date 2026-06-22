import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fires a short, celebratory burst of diamond icons from [origin] (defaults to
/// screen centre) that fan outward, drift up, and fade. Purely visual juice for
/// "you earned diamonds" moments — overlay-based, so it floats above any screen
/// and cleans itself up when the animation ends.
void showCoinBurst(
  BuildContext context, {
  Offset? origin,
  int count = 12,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final size = MediaQuery.of(context).size;
  final start = origin ?? Offset(size.width / 2, size.height / 2);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CoinBurst(
      origin: start,
      count: count,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _CoinBurst extends StatefulWidget {
  final Offset origin;
  final int count;
  final VoidCallback onDone;

  const _CoinBurst({
    required this.origin,
    required this.count,
    required this.onDone,
  });

  @override
  State<_CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<_CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Coin> _coins;

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
      duration: const Duration(milliseconds: 950),
    )..forward().whenComplete(widget.onDone);
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
              final eased = Curves.easeOut.transform(t);
              final dx = math.cos(c.angle) * c.distance * eased;
              // Extra upward drift + slight gravity at the tail.
              final dy = math.sin(c.angle) * c.distance * eased + 30 * t * t;
              return Positioned(
                left: widget.origin.dx + dx - c.size / 2,
                top: widget.origin.dy + dy - c.size / 2,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: t * 3,
                    child: Icon(
                      Icons.diamond_rounded,
                      size: c.size,
                      color: const Color(0xFFFF9D2E),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
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
