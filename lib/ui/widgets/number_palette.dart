import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';

class NumberPalette extends StatefulWidget {
  final ColoringProvider provider;

  const NumberPalette({super.key, required this.provider});

  @override
  State<NumberPalette> createState() => _NumberPaletteState();
}

class _NumberPaletteState extends State<NumberPalette> {
  final ScrollController _scrollController = ScrollController();
  int? _lastSelected;

  ColoringProvider get provider => widget.provider;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps the selected chip visible — auto-advance can jump the selection
  /// to a color that is scrolled off screen.
  void _followSelection(List<int> numbers, int selected) {
    if (_lastSelected == selected) return;
    _lastSelected = selected;
    final index = numbers.indexOf(selected);
    if (index < 0 || !_scrollController.hasClients) return;
    const itemExtent = 62.0; // chip width + margins, approximate
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

    final numbers = art.sortedNumbers.where((n) {
      return provider.fillPercentForNumber(n) < 1.0;
    }).toList();
    if (numbers.isEmpty) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followSelection(numbers, provider.selectedNumber);
    });

    return SizedBox(
      height: 80,
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

          Widget chip = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      color: _textColorForBg(color),
                      size: 24,
                    )
                  : Text(
                      '$number',
                      style: TextStyle(
                        color: _textColorForBg(color),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          );

          if (isSelected) {
            chip = CustomPaint(
              painter: ProgressRingPainter(
                progress: fillPercent.clamp(0.0, 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: chip,
              ),
            );
          } else {
            chip = Padding(
              padding: const EdgeInsets.all(5.0),
              child: chip,
            );
          }

          return GestureDetector(
            onTap: () => provider.selectNumber(number),
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
