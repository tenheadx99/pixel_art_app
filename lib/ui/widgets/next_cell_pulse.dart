import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A tiny always-on-top layer that breathes a soft highlight on the next
/// fillable cell. Lives outside the grid painter so its animation repaints
/// only this layer (a couple of rounded rects) instead of the whole visible
/// grid at 60fps, and it uses no blur. The ticker runs only while there is a
/// cell to highlight. Positioned in screen space from the shared transform so
/// it stays glued to its cell during pan/zoom (same trick as the fill
/// effects overlay).
class NextCellPulse extends StatefulWidget {
  final TransformationController transformController;
  final double cellSize;
  final Size viewerSize;
  final int gridWidth;
  final int gridHeight;
  final (int, int)? cell;

  const NextCellPulse({
    super.key,
    required this.transformController,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
    required this.cell,
  });

  @override
  State<NextCellPulse> createState() => _NextCellPulseState();
}

class _NextCellPulseState extends State<NextCellPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant NextCellPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.cell == null) {
      _ticker.stop();
    } else if (!_ticker.isAnimating) {
      _ticker.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _NextCellPulsePainter(
            cell: widget.cell,
            phase: _ticker,
            transform: widget.transformController,
            cellSize: widget.cellSize,
            viewerSize: widget.viewerSize,
            gridWidth: widget.gridWidth,
            gridHeight: widget.gridHeight,
          ),
        ),
      ),
    );
  }
}

class _NextCellPulsePainter extends CustomPainter {
  final (int, int)? cell;
  final Animation<double> phase;
  final TransformationController transform;
  final double cellSize;
  final Size viewerSize;
  final int gridWidth;
  final int gridHeight;

  _NextCellPulsePainter({
    required this.cell,
    required this.phase,
    required this.transform,
    required this.cellSize,
    required this.viewerSize,
    required this.gridWidth,
    required this.gridHeight,
  }) : super(repaint: Listenable.merge([phase, transform]));

  @override
  void paint(Canvas canvas, Size size) {
    final target = cell;
    if (target == null) return;
    final (row, col) = target;

    final gridLeft = (viewerSize.width - gridWidth * cellSize) / 2;
    final gridTop = (viewerSize.height - gridHeight * cellSize) / 2;
    final sceneCenter = Offset(
      gridLeft + (col + 0.5) * cellSize,
      gridTop + (row + 0.5) * cellSize,
    );
    final matrix = transform.value;
    final center = MatrixUtils.transformPoint(matrix, sceneCenter);
    final cellPx = cellSize * matrix.getMaxScaleOnAxis();

    // Gentle breathing: 0..1..0 over the ticker cycle.
    final breath = 0.5 - 0.5 * math.cos(phase.value * 2 * math.pi);

    final paint = Paint();
    final radius = Radius.circular(cellPx * 0.16);

    // Expanding soft ring.
    final ringSide = cellPx * (1.0 + 0.18 * breath);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cellPx * 0.1).clamp(1.0, 3.5)
      ..color = const Color(0xFF6C63FF)
          .withValues(alpha: 0.35 + 0.4 * (1 - breath));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: ringSide, height: ringSide),
        radius,
      ),
      paint,
    );

    // Soft inner glow that swells with the breath.
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.15 + 0.2 * breath);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: cellPx, height: cellPx),
        radius,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NextCellPulsePainter oldDelegate) =>
      oldDelegate.cell != cell;
}
