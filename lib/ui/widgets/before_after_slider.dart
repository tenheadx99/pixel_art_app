import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/pixel_art.dart';
import 'art_preview_painter.dart';

/// Interactive Before & After comparison widget that lets users slide a split
/// line back and forth to compare the blank grid line-art against the finished colored masterpiece.
class BeforeAfterSlider extends StatefulWidget {
  final PixelArt art;
  final double aspectRatio;
  final bool isDark;

  const BeforeAfterSlider({
    super.key,
    required this.art,
    this.aspectRatio = 1.0,
    required this.isDark,
  });

  static Future<void> showSheet(
    BuildContext context, {
    required PixelArt art,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF181824) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compare_rounded, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 8),
                  Text(
                    'Before & After Reveal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF222222),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Drag the slider to see how your colors brought it to life:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: AspectRatio(
                    aspectRatio: art.gridWidth / art.gridHeight,
                    child: BeforeAfterSlider(art: art, isDark: isDark),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${art.gridWidth}x${art.gridHeight} · ${art.fillableCells} pixels · ${art.colorCount} colors',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Awesome!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _splitPercent = 0.50; // 0.0 to 1.0
  bool _didCrossMidpoint = false;

  void _updateSplit(double localDx, double width) {
    if (width <= 0) return;
    final pct = (localDx / width).clamp(0.02, 0.98);
    if ((pct >= 0.49 && pct <= 0.51) && !_didCrossMidpoint) {
      _didCrossMidpoint = true;
      HapticFeedback.selectionClick();
    } else if (pct < 0.48 || pct > 0.52) {
      _didCrossMidpoint = false;
    }
    setState(() => _splitPercent = pct);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final splitX = w * _splitPercent;

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _updateSplit(details.localPosition.dx, w),
          onTapDown: (details) => _updateSplit(details.localPosition.dx, w),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF14141E) : const Color(0xFFF0F0F4),
              border: Border.all(
                color: widget.isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Stack(
              children: [
                // Base layer: FULLY COLORED artwork (After)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ArtPreviewPainter(
                      art: widget.art,
                      isCompleted: true,
                    ),
                  ),
                ),

                // Top layer: UNCOLORED blank grid (Before), clipped to 0..splitX
                Positioned.fill(
                  child: ClipRect(
                    clipper: _SplitHorizontalClipper(splitX: splitX),
                    child: Container(
                      color: widget.isDark
                          ? const Color(0xFF1A1A26)
                          : const Color(0xFFE8E8EE),
                      child: CustomPaint(
                        painter: ArtPreviewPainter(
                          art: widget.art,
                          isCompleted: false,
                        ),
                      ),
                    ),
                  ),
                ),

                // "BEFORE" badge (top left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Opacity(
                    opacity: (_splitPercent > 0.15) ? 1.0 : (_splitPercent / 0.15),
                    child: _buildTagBadge('BEFORE', Colors.black54),
                  ),
                ),

                // "AFTER" badge (top right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Opacity(
                    opacity: (_splitPercent < 0.85) ? 1.0 : ((1.0 - _splitPercent) / 0.15),
                    child: _buildTagBadge('AFTER', const Color(0xFF00B894)),
                  ),
                ),

                // The vertical dividing bar
                Positioned(
                  left: splitX - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(90),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // The draggable thumb handle knob in the center
                Positioned(
                  left: splitX - 20,
                  top: h / 2 - 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF6C5CE7), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(70),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.code_rounded, // horizontal < > arrows aesthetic
                        size: 22,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(220),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SplitHorizontalClipper extends CustomClipper<Rect> {
  final double splitX;

  _SplitHorizontalClipper({required this.splitX});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, math.max(0.0, splitX), size.height);
  }

  @override
  bool shouldReclip(covariant _SplitHorizontalClipper oldClipper) {
    return oldClipper.splitX != splitX;
  }
}

