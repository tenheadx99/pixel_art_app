import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';

class NumberPalette extends StatefulWidget {
  final ColoringProvider provider;
  final void Function(int number)? onNumberTapped;
  final void Function(int number)? onNumberReTapped;

  const NumberPalette({
    super.key,
    required this.provider,
    this.onNumberTapped,
    this.onNumberReTapped,
  });

  @override
  State<NumberPalette> createState() => _NumberPaletteState();
}

class _NumberPaletteState extends State<NumberPalette> {
  final ScrollController _scrollController = ScrollController();
  int? _lastSelected;

  // A just-completed color's chip sticks around briefly to celebrate (pop to
  // a check, then shrink away) instead of vanishing the instant it finishes.
  static const _celebrationMs = 700;
  final Map<int, Timer> _celebrating = {};
  Set<int> _prevIncomplete = {};

  ColoringProvider get provider => widget.provider;

  @override
  void dispose() {
    for (final timer in _celebrating.values) {
      timer.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Scale curve for a celebrating chip over its lifetime [t] 0..1:
  /// bounce up past full size, hold, then shrink out.
  static double _celebrationScale(double t) {
    if (t < 0.4) {
      return 1.0 + 0.3 * Curves.easeOutBack.transform(t / 0.4);
    }
    if (t < 0.6) return 1.3;
    return 1.3 * (1.0 - Curves.easeInCubic.transform((t - 0.6) / 0.4));
  }

  /// Keeps the selected chip visible — auto-advance can jump the selection
  /// to a color that is scrolled off screen.
  void _followSelection(List<int> numbers, int selected) {
    if (_lastSelected == selected) return;
    _lastSelected = selected;
    final index = numbers.indexOf(selected);
    if (index < 0 || !_scrollController.hasClients) return;
    const itemExtent = 74.0; // chip width (62 selected / 52 unselected) + margins
    final viewport = _scrollController.position.viewportDimension;
    final target = (index * itemExtent - (viewport - itemExtent) / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final art = provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    final incomplete = art.sortedNumbers
        .where((n) => provider.fillPercentForNumber(n) < 1.0)
        .toSet();
    // Pre-fetch counts once per build — O(1) map lookups per chip.
    final counts = {
      for (final n in art.sortedNumbers) n: provider.cellCountsForNumber(n),
    };
    // Numbers that completed since the previous build start their send-off.
    for (final n in _prevIncomplete) {
      if (!incomplete.contains(n) && !_celebrating.containsKey(n)) {
        _celebrating[n] = Timer(
          const Duration(milliseconds: _celebrationMs),
          () {
            if (mounted) {
              setState(() => _celebrating.remove(n));
            } else {
              _celebrating.remove(n);
            }
          },
        );
      }
    }
    _prevIncomplete = incomplete;

    final numbers = art.sortedNumbers
        .where((n) => incomplete.contains(n) || _celebrating.containsKey(n))
        .toList();
    if (numbers.isEmpty) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followSelection(numbers, provider.selectedNumber);
    });

    return SizedBox(
      height: 88,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: numbers.length,
        itemBuilder: (context, index) {
          final number = numbers[index];
          final color =
              art.colorForNumber(number) ?? AppStyle.numberToColor(number);
          final isSelected = provider.selectedNumber == number;
          final fillPercent = provider.fillPercentForNumber(number);
          final isCompleted = fillPercent >= 1.0;
          final (filled, total) = counts[number] ?? (0, 0);
          final remaining = total - filled;

          // Selected chip is 62 px, unselected 52 px — spring-animated.
          final chipSize = isSelected ? 62.0 : 52.0;

          Widget chip = AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            width: chipSize,
            height: chipSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? color.withAlpha(100)
                      : Colors.black.withAlpha(20),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      color: _textColorForBg(color),
                      size: isSelected ? 28 : 24,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            color: _textColorForBg(color),
                            fontSize: isSelected ? 20 : 16,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        if (!isCompleted && total > 0)
                          Text(
                            '$remaining',
                            style: TextStyle(
                              color: _textColorForBg(color).withAlpha(180),
                              fontSize: isSelected ? 9 : 8,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
            ),
          );

          // Progress ring on every chip: thick + green for selected,
          // thin + white/grey for unselected (shows at-a-glance progress).
          chip = CustomPaint(
            painter: ProgressRingPainter(
              progress: fillPercent.clamp(0.0, 1.0),
              strokeWidth: isSelected ? 3.5 : 2.0,
              progressColor: isSelected
                  ? const Color(0xFF4CAF50)
                  : Colors.white.withAlpha(200),
              backgroundColor: isSelected
                  ? const Color(0xFFE0E0E0)
                  : Colors.white.withAlpha(60),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: chip,
            ),
          );

          if (_celebrating.containsKey(number)) {
            chip = TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: _celebrationMs),
              builder: (context, t, child) => Transform.scale(
                scale: _celebrationScale(t),
                child: child,
              ),
              child: chip,
            );
          }

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (provider.selectedNumber == number) {
                widget.onNumberReTapped?.call(number);
              } else {
                provider.selectNumber(number);
                widget.onNumberTapped?.call(number);
              }
            },
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 12.0 : 6.0,
                  right: index == numbers.length - 1 ? 12.0 : 6.0,
                ),
                child: chip,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _textColorForBg(Color bg) {
    final luminance = (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b);
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  ProgressRingPainter({
    required this.progress,
    this.progressColor = const Color(0xFF4CAF50), // Green progress
    this.backgroundColor = const Color(0xFFE0E0E0), // Grey track
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Draw background grey circle
    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    // Draw foreground green progress arc
    if (progress > 0) {
      paint.color = progressColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        progress * 2 * pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
