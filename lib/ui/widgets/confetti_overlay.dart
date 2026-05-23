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
    final particles = 60;
    for (var i = 0; i < particles; i++) {
      final px = rng.nextDouble();
      final py = rng.nextDouble();
      final speed = 0.3 + rng.nextDouble() * 0.5;
      final sway = sin(progress * 8 + px * 10) * 15;
      final x = px * size.width + sway;
      final y = (py + speed * progress) * size.height;
      if (y > size.height + 20) continue;
      final hue = (px * 360).round();
      final color = HSLColor.fromAHSL(
        1.0 - progress * 0.6,
        hue.toDouble(),
        0.8,
        0.6,
      ).toColor();
      final rot = progress * 20 + px * 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 5),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
