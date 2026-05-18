import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../data/models/pixel_art.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/widgets/pixel_grid.dart';
import '../../ui/widgets/number_palette.dart';
import '../../ui/widgets/number_toolbar.dart';

class ColoringScreen extends StatefulWidget {
  final PixelArt art;

  const ColoringScreen({super.key, required this.art});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with SingleTickerProviderStateMixin {
  double _cellSize = AppConfig.defaultCellSize;
  final TransformationController _transformController = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ColoringProvider>().loadArt(widget.art);
      _adjustCellSize();
    });
  }

  void _adjustCellSize() {
    final screenSize = MediaQuery.of(context).size;
    final maxGridWidth = screenSize.width - 32;
    final cellW = maxGridWidth / widget.art.gridWidth;
    _cellSize = cellW.clamp(AppConfig.minCellSize, AppConfig.maxCellSize);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ColoringProvider>(
      builder: (context, provider, _) {
        if (provider.isComplete && !_confettiController.isAnimating) {
          _confettiController.forward();
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFFF8F9FF)
                          : const Color(0xFF1A1A2E),
                      Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFFE8E5FF)
                          : const Color(0xFF16213E),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, provider),
                    Expanded(
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: RepaintBoundary(
                          key: _repaintKey,
                          child: Center(
                            child: PixelGrid(
                              provider: provider,
                              cellSize: _cellSize,
                              onCellTap: (row, col) {
                                provider.tryFillCell(row, col);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildBottomSection(context, provider),
                  ],
                ),
              ),
              if (provider.isComplete)
                _ConfettiOverlay(controller: _confettiController),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, ColoringProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppStyle.glassmorphism(context),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppStyle.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppStyle.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.art.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                _buildProgressBar(provider.progress),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(provider.progress * 100).toInt()}%',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppStyle.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _saveArtwork(context, provider),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppStyle.primary, AppStyle.secondary],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppStyle.primary.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.save, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: double.infinity * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6C5CE7),
                    Color(0xFFFD79A8),
                    Color(0xFFFFD700),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, ColoringProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumberToolbar(
            provider: provider,
            onSave: () => _saveArtwork(context, provider),
            onReset: () => _confirmReset(context, provider),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 130),
            padding: const EdgeInsets.all(8),
            decoration: AppStyle.glassmorphism(context),
            child: NumberPalette(provider: provider),
          ),
        ],
      ),
    );
  }

  Future<void> _saveArtwork(BuildContext context, ColoringProvider provider) async {
    final storageService = context.read<LocalStorageService>();
    final screenshotService = ScreenshotService(storageService);
    final pngBytes = await screenshotService.captureAsPng(_repaintKey);
    if (pngBytes == null) return;

    final path = await screenshotService.saveArtwork(pngBytes, widget.art.name);
    if (path == null) return;

    if (context.mounted) {
      context.read<GalleryProvider>().markCompleted(widget.art.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Artwork saved!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF00B894),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmReset(BuildContext context, ColoringProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Artwork'),
        content: const Text('This will clear all your progress. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetArt();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _ConfettiOverlay extends StatefulWidget {
  final AnimationController controller;

  const _ConfettiOverlay({required this.controller});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late List<_ConfettiParticle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      60,
      (i) => _ConfettiParticle(
        x: _random.nextDouble(),
        y: -0.2 - _random.nextDouble() * 0.5,
        speed: 0.3 + _random.nextDouble() * 0.5,
        size: 6 + _random.nextDouble() * 8,
        color: AppColors.categoryColors[i % AppColors.categoryColors.length],
        angle: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      ),
    );
    widget.controller.addListener(() {
      if (widget.controller.isAnimating) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.value;
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(particles: _particles, progress: progress),
      ),
    );
  }
}

class _ConfettiParticle {
  double x, y, speed, size, angle, rotationSpeed;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.angle,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = (p.y + p.speed * progress) * size.height;
      final sway = sin(progress * 8 + p.x * 10) * 15;
      final currentX = (p.x * size.width + sway);
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final currentAngle = p.angle + p.rotationSpeed * progress;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentAngle);

      final paint = Paint()
        ..color = p.color.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 0.6,
            height: p.size,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => progress != oldDelegate.progress;
}
