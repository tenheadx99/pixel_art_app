import 'package:flutter/material.dart';

import '../motion.dart';

/// One-shot fade-and-rise entrance, staggered by [slot] (grid index, list
/// position…). A plain [TweenAnimationBuilder] — no controllers — per the
/// home-grid perf note, so it is safe to sprinkle across whole screens.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.slot,
    required this.child,
    this.stepMs = 45,
    this.maxSlots = 8,
  });

  final int slot;
  final Widget child;

  /// Delay added per slot.
  final int stepMs;

  /// Slots wrap past this so deep lists don't wait noticeably.
  final int maxSlots;

  @override
  Widget build(BuildContext context) {
    final delayMs = (slot % maxSlots) * stepMs;
    final totalMs = 250 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Motion.standard),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
