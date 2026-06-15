import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatelessWidget {
  final Animation<double> animation;

  const ConfettiOverlay({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        if (!animation.isAnimating) return const SizedBox.shrink();
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(animation.value),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rng = Random(42);
    final particles = 110;
    final paint = Paint();
    for (var i = 0; i < particles; i++) {
      final px = rng.nextDouble();
      final py = rng.nextDouble();
      final speed = 0.3 + rng.nextDouble() * 0.5;
      // Per-particle character: size, shape and sway differ so the burst
      // reads as celebratory rather than a uniform sheet.
      final scale = 0.7 + rng.nextDouble() * 1.4; // 0.7x–2.1x
      final shape = rng.nextInt(3); // 0 rect, 1 circle, 2 thin streamer
      final swayAmp = 14 + rng.nextDouble() * 22;
      final sway = sin(progress * 8 + px * 12) * swayAmp;
      final x = px * size.width + sway;
      final y = (py + speed * progress) * size.height;
      if (y > size.height + 24) continue;
      final hue = (px * 360).round();
      final color = HSLColor.fromAHSL(
        1.0 - progress * 0.5,
        hue.toDouble(),
        0.85,
        0.62,
      ).toColor();
      paint.color = color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 22 + px * 30);
      if (shape == 1) {
        canvas.drawCircle(Offset.zero, 4 * scale, paint);
      } else if (shape == 2) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: 4 * scale, height: 11 * scale),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: 10 * scale, height: 6 * scale),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
