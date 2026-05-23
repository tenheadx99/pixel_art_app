import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../data/models/pixel_art.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/widgets/pixel_grid.dart';
import '../../ui/widgets/number_palette.dart';
import '../../ui/widgets/number_toolbar.dart';
import '../../ui/widgets/confetti_overlay.dart';

class ColoringScreen extends StatefulWidget {
  final PixelArt art;

  const ColoringScreen({super.key, required this.art});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with TickerProviderStateMixin {
  double _cellSize = AppConfig.defaultCellSize;
  final TransformationController _transformController = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _confettiController;
  late AnimationController _replayController;
  List<(int, int)> _replayActions = [];
  int _replayIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _replayController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ColoringProvider>().loadArt(widget.art);
      _adjustCellSize();
    });
  }

  void _adjustCellSize() {
    final screenSize = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final availableWidth = screenSize.width - 32;
    final availableHeight = screenSize.height - pad.top - pad.bottom - 64 - 200;
    if (widget.art.gridWidth <= 0 || widget.art.gridHeight <= 0) return;
    final fromW = availableWidth / widget.art.gridWidth;
    final fromH = availableHeight / widget.art.gridHeight;
    final cell = fromW < fromH ? fromW : fromH;
    _cellSize = cell.clamp(AppConfig.minCellSize, AppConfig.maxCellSize);
    if (!_cellSize.isFinite) _cellSize = AppConfig.defaultCellSize;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _transformController.dispose();
    _confettiController.dispose();
    _replayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ColoringProvider, AppSettingsProvider>(
      builder: (context, provider, settings, _) {
        if (provider.isComplete && !_confettiController.isAnimating) {
          _confettiController.forward();
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.light
                    ? [const Color(0xFFF8F9FF), const Color(0xFFE8E5FF)]
                    : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, provider),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildGrid(provider, settings),
                        ConfettiOverlay(animation: _confettiController),
                        if (provider.isComplete)
                          _buildReplayButton(provider),
                      ],
                    ),
                  ),
                  _buildBottomSection(context, provider, settings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplayButton(ColoringProvider provider) {
    return Positioned(
      bottom: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => _startTimeLapse(provider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_replayController.isAnimating ? Icons.stop : Icons.replay, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _replayController.isAnimating ? 'Replaying...' : 'Replay',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTimeLapse(ColoringProvider provider) {
    if (provider.timeLapse.isEmpty) return;
    if (_replayController.isAnimating) {
      _replayController.reset();
      provider.resetArt();
      setState(() {});
      return;
    }
    provider.resetArt();
    _replayActions = List.from(provider.timeLapse);
    _replayIndex = 0;
    _replayController.duration = Duration(milliseconds: max(1000, _replayActions.length * 30));
    _replayController.addListener(() {
      final target = (_replayController.value * _replayActions.length).floor();
      while (_replayIndex < target && _replayIndex < _replayActions.length) {
        final (r, c) = _replayActions[_replayIndex];
        provider.timeLapseStep(r, c);
        _replayIndex++;
      }
    });
    _replayController.forward();
  }

  Widget _buildTopBar(BuildContext context, ColoringProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
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
                Text(widget.art.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: provider.progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFFFD79A8), Color(0xFFFFD700)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(provider.progress * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppStyle.primary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _saveArtwork(context, provider),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppStyle.primary, AppStyle.secondary]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x3D6C5CE7), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.save, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ColoringProvider provider, AppSettingsProvider settings) {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.5,
      maxScale: 4.0,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Center(
          child: PixelGrid(
            provider: provider,
            cellSize: _cellSize,
            brushSize: provider.brushSize,
            isEraseMode: provider.isEraseMode,
            colorblindMode: settings.colorblindMode,
            onCellTap: (row, col) {
              final filled = provider.tryFillCell(row, col);
              if (filled) HapticFeedback.lightImpact();
            },
            onCellLongPress: (row, col) {
              _showColorPreview(context, provider, row, col);
            },
          ),
        ),
      ),
    );
  }

  void _showColorPreview(BuildContext context, ColoringProvider provider, int row, int col) {
    final art = provider.currentArt;
    if (art == null) return;
    final num = art.grid[row][col];
    if (num == 0) return;
    final color = provider.filledColors[num] ?? AppStyle.numberToColor(num);
    final isFilled = provider.filledGrid[row][col] > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withAlpha(30)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Number $num', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(isFilled ? 'Already filled' : 'Tap to fill this color',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (!isFilled)
            ElevatedButton(
              onPressed: () {
                provider.selectNumber(num);
                Navigator.pop(ctx);
              },
              child: const Text('Select'),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context, ColoringProvider provider, AppSettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumberToolbar(
            provider: provider,
            settings: settings,
            onSave: () => _saveArtwork(context, provider),
            onReset: () => _confirmReset(context, provider),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(60)),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
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
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Text('Artwork saved!')]),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { provider.resetArt(); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
