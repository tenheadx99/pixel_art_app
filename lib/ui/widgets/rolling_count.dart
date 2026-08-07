import 'package:flutter/material.dart';

import '../motion.dart';

/// Number text that rolls to its new value instead of snapping — used for
/// diamond/XP counters so earnings feel like they land.
class RollingCount extends StatelessWidget {
  const RollingCount(
    this.value, {
    super.key,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Motion.standard,
      builder: (context, v, _) =>
          Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}
