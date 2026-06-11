import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import '../../data/models/pixel_art.dart';
import '../../data/models/user_artwork.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/iap_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../data/services/timelapse_service.dart';
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
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _confettiController;
  late AnimationController _replayController;
  late AnimationController _gridFadeController;
  List<(int, int)> _replayActions = [];
  int _replayIndex = 0;
  List<List<int>>? _savedGridState;
  bool _wasComplete = false;
  bool _sharingGif = false;
  ColoringProvider? _coloringProvider;
  AppSettingsProvider? _settings;
  Size _viewerSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _replayController.addListener(_onReplayTick);
    _replayController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishReplay();
    });
    _gridFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ColoringProvider>();
      provider.loadArt(widget.art);
      _adjustCellSize();
      _wasComplete = provider.isComplete;
      if (_wasComplete) _gridFadeController.value = 1.0;
      _coloringProvider = provider..addListener(_onProviderChanged);
      _settings = context.read<AppSettingsProvider>()
        ..addListener(_onSettingsChanged);
    });
  }

  /// Reacts to provider events: achievement unlocks and the
  /// incomplete -> complete transition (grid fade + interstitial preload).
  void _onProviderChanged() {
    final provider = _coloringProvider;
    if (provider == null || !mounted) return;

    final unlocked = provider.lastUnlockedAchievement;
    if (unlocked != null) {
      provider.clearLastUnlockedAchievement();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Achievement unlocked: ${provider.achievementName(unlocked)}',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF6C5CE7),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (provider.isComplete && !_wasComplete) {
      _wasComplete = true;
      _gridFadeController.forward();
      if (!(_settings?.isProUser ?? false)) {
        context.read<AdService>().loadInterstitialAd();
      }
    } else if (!provider.isComplete && _wasComplete) {
      _wasComplete = false;
      _gridFadeController.value = 0;
    }
  }

  /// Wand credits from IAP land in storage via AppSettingsProvider; pull them
  /// into the live provider so the toolbar count updates immediately.
  void _onSettingsChanged() {
    _coloringProvider?.syncWandsFromStorage();
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
    _coloringProvider?.removeListener(_onProviderChanged);
    _settings?.removeListener(_onSettingsChanged);
    _transformController.dispose();
    _confettiController.dispose();
    _replayController.dispose();
    _gridFadeController.dispose();
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
                        if (provider.isComplete) _buildCompletionBar(provider),
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

  Widget _buildCompletionBar(ColoringProvider provider) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompletionAction(
                icon: _replayController.isAnimating ? Icons.stop : Icons.replay,
                label: _replayController.isAnimating ? 'Stop' : 'Replay',
                onTap: () => _startTimeLapse(provider),
              ),
              _CompletionAction(
                icon: Icons.image_rounded,
                label: 'Share',
                onTap: () => _sharePng(provider),
              ),
              _CompletionAction(
                icon: Icons.movie_rounded,
                label: _sharingGif ? 'Rendering…' : 'Share GIF',
                onTap: _sharingGif ? null : () => _shareTimelapse(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePng(ColoringProvider provider) async {
    final storageService = context.read<LocalStorageService>();
    final screenshotService = ScreenshotService(storageService);
    final pngBytes = await screenshotService.captureAsPng(_repaintKey);
    if (pngBytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pixely_${widget.art.id}.png',
    );
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'I just finished "${widget.art.name}" in Pixely! 🎨',
    );
  }

  Future<void> _shareTimelapse(ColoringProvider provider) async {
    if (provider.timeLapse.isEmpty) {
      _showInfoSnack('No painting history to replay for this artwork.');
      return;
    }
    setState(() => _sharingGif = true);
    try {
      final bytes = await TimelapseService.renderGif(
        art: widget.art,
        actions: provider.timeLapse,
      );
      if (bytes == null) {
        _showInfoSnack('Could not render the time-lapse.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pixely_${widget.art.id}_timelapse.gif');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/gif')],
        text: 'Watch me paint "${widget.art.name}" in Pixely! 🎨',
      );
    } finally {
      if (mounted) setState(() => _sharingGif = false);
    }
  }

  void _showInfoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startTimeLapse(ColoringProvider provider) {
    if (_replayController.isAnimating) {
      _replayController.stop();
      _replayController.reset();
      _finishReplay();
      return;
    }
    final art = provider.currentArt;
    if (art == null || provider.timeLapse.isEmpty) return;
    _replayActions = List.from(provider.timeLapse);
    _replayIndex = 0;
    _savedGridState = provider.getGridState();
    provider.restoreGridState(
      List.generate(art.gridHeight, (_) => List.filled(art.gridWidth, 0)),
    );
    _replayController.duration = Duration(
      milliseconds: max(1000, _replayActions.length * 30),
    );
    _replayController.forward(from: 0);
    setState(() {});
  }

  void _onReplayTick() {
    if (_replayActions.isEmpty) return;
    final provider = context.read<ColoringProvider>();
    final target = (_replayController.value * _replayActions.length).floor();
    while (_replayIndex < target && _replayIndex < _replayActions.length) {
      final (r, c) = _replayActions[_replayIndex];
      provider.timeLapseStep(r, c);
      _replayIndex++;
    }
  }

  void _finishReplay() {
    if (_savedGridState != null) {
      context.read<ColoringProvider>().restoreGridState(_savedGridState!);
      _savedGridState = null;
    }
    _replayActions = [];
    if (mounted) setState(() {});
  }

  Widget _buildTopBar(BuildContext context, ColoringProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppStyle.glassmorphism(context),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Completed artwork is a natural break: show the preloaded
              // interstitial on the way out (free users only).
              if (provider.isComplete && !(_settings?.isProUser ?? true)) {
                context.read<AdService>().showInterstitialAd();
              }
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppStyle.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: AppStyle.primary,
              ),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                         Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade200
                                : Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: provider.progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00F0FF), // Cyber Cyan
                                  Color(0xFF8A2BE2), // Indigo
                                  Color(0xFFFF007F), // Neon Pink
                                ],
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
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3D6C5CE7),
                    blurRadius: 8,
                    offset: Offset(0, 3),
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

  Widget _buildGrid(ColoringProvider provider, AppSettingsProvider settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewerSize = Size(constraints.maxWidth, constraints.maxHeight);
        // One finger paints, two fingers pan/zoom (scale gestures include
        // translation), so single-finger pan stays free for drag-to-paint.
        return InteractiveViewer(
          transformationController: _transformController,
          panEnabled: false,
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
                gridLineOpacity: 1.0 - _gridFadeController.value,
                onCellTap: (row, col) => provider.tryFillCell(row, col),
                onCellLongPress: (row, col) {
                  _showColorPreview(context, provider, row, col);
                },
                onCellDragStart: () {
                  if (!provider.isMagicWandMode) provider.beginStroke();
                },
                onCellDrag: provider.strokeFill,
                onCellDragEnd: provider.endStroke,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showColorPreview(
    BuildContext context,
    ColoringProvider provider,
    int row,
    int col,
  ) {
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withAlpha(30)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Number $num',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              isFilled ? 'Already filled' : 'Tap to fill this color',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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

  Widget _buildBottomSection(
    BuildContext context,
    ColoringProvider provider,
    AppSettingsProvider settings,
  ) {
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
            onHint: () => _useHint(provider, settings),
            onWandEmpty: () => _showRefillDialog(
              provider: provider,
              settings: settings,
              forHints: false,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 132,
            padding: const EdgeInsets.all(8),
            decoration: AppStyle.glassmorphism(context),
            child: NumberPalette(provider: provider),
          ),
        ],
      ),
    );
  }

  /// Spends a hint to fill one correct cell and zooms the viewport to it.
  /// With no hints left, offers a rewarded ad or a purchase instead.
  void _useHint(ColoringProvider provider, AppSettingsProvider settings) {
    if (settings.hintsAvailable <= 0) {
      _showRefillDialog(provider: provider, settings: settings, forHints: true);
      return;
    }
    final target = provider.applyHint();
    if (target == null) {
      _showInfoSnack('Nothing left to fill!');
      return;
    }
    settings.useHint();
    _zoomToCell(target.$1, target.$2);
  }

  void _zoomToCell(int row, int col) {
    if (_viewerSize == Size.zero) return;
    const scale = 2.5;
    final art = widget.art;
    final gridLeft = (_viewerSize.width - art.gridWidth * _cellSize) / 2;
    final gridTop = (_viewerSize.height - art.gridHeight * _cellSize) / 2;
    final cx = gridLeft + (col + 0.5) * _cellSize;
    final cy = gridTop + (row + 0.5) * _cellSize;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(
        _viewerSize.width / 2 - scale * cx,
        _viewerSize.height / 2 - scale * cy,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _showRefillDialog({
    required ColoringProvider provider,
    required AppSettingsProvider settings,
    required bool forHints,
  }) {
    final adService = context.read<AdService>();
    final iapService = context.read<IAPService>();
    final label = forHints ? 'hints' : 'magic wands';
    final adAmount = forHints
        ? AppConstants.hintsPerRewardedAd
        : AppConstants.wandsPerRewardedAd;
    final buyAmount = forHints
        ? AppConstants.hintsPerPurchase
        : AppConstants.wandsPerPurchase;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              forHints ? Icons.lightbulb_rounded : Icons.auto_fix_high_rounded,
              color: AppStyle.primary,
            ),
            const SizedBox(width: 8),
            Text('Out of ${forHints ? 'Hints' : 'Wands'}'),
          ],
        ),
        content: Text('Get more $label to keep the flow going!'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text('Watch Ad (+$adAmount)'),
            onPressed: () {
              Navigator.pop(ctx);
              adService.loadRewardedAd(
                onLoaded: () => adService.showRewardedAd(
                  onRewarded: () {
                    if (forHints) {
                      settings.addHints(adAmount);
                    } else {
                      provider.addMagicWands(adAmount);
                    }
                    _showInfoSnack('+$adAmount $label earned!');
                  },
                ),
                onFailed: () =>
                    _showInfoSnack('No ad available right now — try again later.'),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text('Buy $buyAmount'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              iapService.buyConsumable(
                forHints
                    ? AppConstants.hintProductId
                    : AppConstants.wandPackProductId,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveArtwork(
    BuildContext context,
    ColoringProvider provider,
  ) async {
    final storageService = context.read<LocalStorageService>();
    final databaseService = context.read<DatabaseService>();
    final screenshotService = ScreenshotService(storageService);
    final pngBytes = await screenshotService.captureAsPng(_repaintKey);
    if (pngBytes == null) return;
    final path = await screenshotService.saveArtwork(pngBytes, widget.art.name);
    if (path == null) return;
    await databaseService.saveArtwork(
      UserArtwork(
        id: const Uuid().v4(),
        pixelArtId: widget.art.id,
        name: widget.art.name,
        filePath: path,
        dateCreated: DateTime.now(),
        completionPercent: (provider.progress * 100).round(),
      ).toJson(),
    );
    if (context.mounted) {
      if (provider.isComplete) {
        context.read<GalleryProvider>().markCompleted(widget.art.id);
      }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

class _CompletionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _CompletionAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap == null ? Colors.white38 : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
