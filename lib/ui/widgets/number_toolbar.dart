import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../theme/app_style.dart';

class NumberToolbar extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final VoidCallback? onHint;

  const NumberToolbar({
    super.key,
    required this.provider,
    required this.settings,
    this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final brushActive = !provider.isEraseMode && !provider.isMagicWandMode && !provider.isBombMode;
    final bombActive = provider.isBombMode;
    final wandActive = provider.isMagicWandMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Paintbrush Tool (Cycles brush size: 1, 2, 3)
          _ToolCircleButton(
            icon: const Icon(
              Icons.brush_rounded,
              color: Colors.pinkAccent,
              size: 24,
            ),
            badgeValue: '${provider.brushSize}',
            isActive: brushActive,
            onTap: () {
              // Cycle brush size: 1 -> 2 -> 3 -> 1
              final nextSize = provider.brushSize == 3 ? 1 : provider.brushSize + 1;
              provider.setBrushSize(nextSize);
              // Make sure we are in brush painting mode
              if (provider.isEraseMode || provider.isMagicWandMode || provider.isBombMode) {
                if (provider.isEraseMode) provider.toggleEraseMode();
                if (provider.isMagicWandMode) provider.toggleMagicWandMode();
                if (provider.isBombMode) provider.toggleBombMode();
              }
            },
          ),

          // 2. Bomb Tool (Fills 3x3 correct pixels)
          _ToolCircleButton(
            icon: SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(
                painter: const BombIconPainter(),
              ),
            ),
            badgeValue: '${provider.bombsCount}',
            isActive: bombActive,
            onTap: () {
              provider.toggleBombMode();
            },
          ),

          // 3. Paint Bucket (Contiguous magic wand fill)
          _ToolCircleButton(
            icon: const Icon(
              Icons.format_color_fill_rounded,
              color: Colors.blueAccent,
              size: 24,
            ),
            badgeValue: '${provider.magicWandsCount}',
            isActive: wandActive,
            onTap: () {
              provider.toggleMagicWandMode();
            },
          ),

          // 4. Hint (Lightbulb)
          _ToolCircleButton(
            icon: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.orangeAccent,
              size: 24,
            ),
            badgeValue: '${settings.hintsAvailable}',
            isActive: false,
            onTap: onHint,
          ),
        ],
      ),
    );
  }
}

class _ToolCircleButton extends StatelessWidget {
  final Widget icon;
  final String badgeValue;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToolCircleButton({
    required this.icon,
    required this.badgeValue,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White Circular Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppStyle.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? AppStyle.primary.withAlpha(40)
                      : Colors.black.withAlpha(20),
                  blurRadius: isActive ? 12 : 8,
                  spreadRadius: isActive ? 1 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: icon,
            ),
          ),
          // Orange Badge in Top Right
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  badgeValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BombIconPainter extends CustomPainter {
  const BombIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(size.width, size.height) * 0.35;

    // Body (dark slate blue)
    final bodyPaint = Paint()
      ..color = const Color(0xFF2E313E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 1, cy + 1), radius, bodyPaint);

    // Body Highlight (white with low opacity)
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(70)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 1 - radius * 0.3, cy + 1 - radius * 0.3), radius * 0.25, highlightPaint);

    // Fuse cap (grey)
    final capPaint = Paint()
      ..color = const Color(0xFF7E8494)
      ..style = PaintingStyle.fill;
    final capPath = Path()
      ..moveTo(cx - 3, cy - radius + 1)
      ..lineTo(cx + 3, cy - radius + 1)
      ..lineTo(cx + 4, cy - radius - 2)
      ..lineTo(cx - 4, cy - radius - 2)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Fuse wire (grey curve)
    final fusePaint = Paint()
      ..color = const Color(0xFF7E8494)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final fusePath = Path()
      ..moveTo(cx, cy - radius - 2)
      ..quadraticBezierTo(cx + 4, cy - radius - 8, cx + 8, cy - radius - 5);
    canvas.drawPath(fusePath, fusePaint);

    // Fuse spark (orange/yellow star)
    final sparkPaint = Paint()
      ..color = const Color(0xFFFF9E00)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + 8, cy - radius - 5), 2.5, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
