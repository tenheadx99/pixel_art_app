import 'package:flutter/material.dart';

/// A glowing chromatic / neon vignette on screen edges during Zen Overdrive mode.
/// Pulses smoothly and creates an immersive tactile flow state while painting.
class ZenOverdriveVignette extends StatefulWidget {
  final bool active;
  final Widget? child;

  const ZenOverdriveVignette({
    super.key,
    required this.active,
    this.child,
  });

  @override
  State<ZenOverdriveVignette> createState() => _ZenOverdriveVignetteState();
}

class _ZenOverdriveVignetteState extends State<ZenOverdriveVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.active) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ZenOverdriveVignette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.child != null) widget.child!,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: widget.active ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            onEnd: () {
              if (!widget.active && _pulseController.isAnimating) {
                _pulseController.stop();
              }
            },
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ZenVignettePainter(
                    pulse: _pulseController.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ZenVignettePainter extends CustomPainter {
  final double pulse; // 0.0 -> 1.0

  _ZenVignettePainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final baseAlpha = 0.35 + 0.35 * pulse; // 0.35 -> 0.70 breathing intensity

    // 1. Edge Vignette Gradients: Neon Prismatic / Golden Shimmer
    // Top gradient
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD700).withValues(alpha: (baseAlpha * 0.75).clamp(0.0, 1.0)),
          const Color(0xFFFF007F).withValues(alpha: (baseAlpha * 0.35).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.16));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.16), topPaint);

    // Bottom gradient
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: (baseAlpha * 0.75).clamp(0.0, 1.0)),
          const Color(0xFFFF007F).withValues(alpha: (baseAlpha * 0.35).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height * 0.84, size.width, size.height * 0.16));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.84, size.width, size.height * 0.16), bottomPaint);

    // Left gradient
    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFFF9100).withValues(alpha: (baseAlpha * 0.6).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.12, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.12, size.height), leftPaint);

    // Right gradient
    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: (baseAlpha * 0.6).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.88, 0, size.width * 0.12, size.height));
    canvas.drawRect(Rect.fromLTWH(size.width * 0.88, 0, size.width * 0.12, size.height), rightPaint);

    // 2. Glowing Inner Border Stroke
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + pulse * 2.0
      ..color = const Color(0xFFFFD700).withValues(alpha: (baseAlpha * 0.5).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(rect.deflate(2), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ZenVignettePainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}

