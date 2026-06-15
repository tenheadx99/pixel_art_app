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
import '../../ui/widgets/ad_banner.dart';
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
  late AnimationController _zoomAnimController;
  Matrix4Tween? _zoomTween;
  List<(int, int)> _replayActions = [];
  int _replayIndex = 0;
  List<List<int>>? _savedGridState;
  bool _wasComplete = false;
  bool _sharingGif = false;
  ColoringProvider? _coloringProvider;
  AppSettingsProvider? _settings;
  AdService? _adService;
  Size _viewerSize = Size.zero;
  final DateTime _sessionStart = DateTime.now();

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
    );
    _zoomAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..addListener(() {
          final tween = _zoomTween;
          if (tween == null) return;
          _transformController.value = tween.evaluate(
            CurvedAnimation(
              parent: _zoomAnimController,
              curve: Curves.easeOutCubic,
            ),
          );
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ColoringProvider>();
      provider.loadArt(widget.art);
      _adjustCellSize();
      // Clear any carry-over from the previously opened artwork.
      _confettiController.reset();
      _wasComplete = provider.isComplete;
      _gridFadeController.value = _wasComplete ? 1.0 : 0.0;
      _coloringProvider = provider..addListener(_onProviderChanged);
      _settings = context.read<AppSettingsProvider>()
        ..addListener(_onSettingsChanged);
      _adService = context.read<AdService>();
      // Preload the session-exit interstitial; the capping logic decides
      // later whether it actually shows.
      if (!(_settings?.isProUser ?? false)) {
        _adService!.loadInterstitialAd();
      }
      _maybeShowLongPressTip();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF6C5CE7),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (provider.isComplete && !_wasComplete) {
      _wasComplete = true;
      _gridFadeController.forward();
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

  /// Surfaces the otherwise-hidden long-press color preview, once ever.
  void _maybeShowLongPressTip() {
    final storage = context.read<LocalStorageService>();
    const key = 'tip_longpress_shown';
    if (storage.getBool(key)) return;
    storage.setBool(key, true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _showInfoSnack('Tip: long-press any cell to preview its color');
      }
    });
  }

  /// Leaving a coloring session is the one interruption point users accept.
  /// AdService applies the caps (min session length, cooldown, first session,
  /// recent rewarded); this just reports the session.
  void _maybeShowExitInterstitial() {
    final adService = _adService;
    if (adService == null || (_settings?.isProUser ?? true)) return;
    final session = DateTime.now().difference(_sessionStart);
    if (adService.canShowSessionInterstitial(session)) {
      adService.showInterstitialAd();
    }
  }

  void _adjustCellSize() {
    final screenSize = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final availableWidth = screenSize.width - 32;
    // Top bar (~64) + toolbar/palette/banner (~250).
    final availableHeight = screenSize.height - pad.top - pad.bottom - 64 - 250;
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
    // Flush any pending debounced autosave so the last few strokes before
    // leaving are never lost (e.g. a quick back-press after painting).
    _coloringProvider?.saveProgress();
    _coloringProvider?.removeListener(_onProviderChanged);
    _settings?.removeListener(_onSettingsChanged);
    _transformController.dispose();
    _confettiController.dispose();
    _replayController.dispose();
    _gridFadeController.dispose();
    _zoomAnimController.dispose();
    super.dispose();
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(
      begin: _transformController.value.clone(),
      end: target,
    );
    _zoomAnimController.forward(from: 0);
  }

  /// Zooms by [factor] keeping the viewport center fixed. A factor of 0
  /// resets to the fitted view.
  void _zoomBy(double factor) {
    if (_viewerSize == Size.zero) return;
    if (factor == 0) {
      _animateZoomTo(Matrix4.identity());
      return;
    }
    final current = _transformController.value.getMaxScaleOnAxis();
    final next = (current * factor)
        .clamp(0.5, max(4.0, 28.0 / _cellSize))
        .toDouble();
    final center = Offset(_viewerSize.width / 2, _viewerSize.height / 2);
    final scene = _transformController.toScene(center);
    _animateZoomTo(
      Matrix4.identity()
        ..translateByDouble(
          center.dx - next * scene.dx,
          center.dy - next * scene.dy,
          0,
          1,
        )
        ..scaleByDouble(next, next, next, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ColoringProvider, AppSettingsProvider>(
      builder: (context, provider, settings, _) {
        // The provider is app-scoped and loadArt runs post-frame, so the
        // first frame still carries the PREVIOUS artwork's state. Never let
        // stale completion trigger confetti/completion UI for this art.
        final isCurrentArt = provider.currentArt?.id == widget.art.id;
        final isComplete = isCurrentArt && provider.isComplete;
        if (isComplete && !_confettiController.isAnimating) {
          _confettiController.forward();
        }

        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _maybeShowExitInterstitial();
          },
          child: Scaffold(
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
                  _buildTopBar(context, provider, isComplete),
                  Expanded(
                    child: Stack(
                      children: [
                        if (isCurrentArt) _buildGrid(provider, settings),
                        _buildZoomControls(),
                        if (provider.isEraseMode || provider.isMagicWandMode)
                          _buildModePill(provider),
                        ConfettiOverlay(animation: _confettiController),
                        if (isComplete) _buildCompletionBar(provider),
                      ],
                    ),
                  ),
                  _buildBottomSection(context, provider, settings),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        children: [
          _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1.4)),
          const SizedBox(height: 6),
          _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(1 / 1.4)),
          const SizedBox(height: 6),
          _ZoomButton(icon: Icons.fit_screen_rounded, onTap: () => _zoomBy(0)),
        ],
      ),
    );
  }

  /// Clear feedback that a destructive/special mode is active — the toolbar
  /// label alone is easy to miss.
  Widget _buildModePill(ColoringProvider provider) {
    final isErase = provider.isEraseMode;
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isErase ? const Color(0xFFFF6B6B) : const Color(0xFF9C27B0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isErase ? Icons.cleaning_services : Icons.auto_fix_high_rounded,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isErase ? 'Eraser on' : 'Magic wand: tap an area',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Suggests another piece to color right after finishing one.
  void _openNextArt() {
    final gallery = context.read<GalleryProvider>();
    final settings = context.read<AppSettingsProvider>();
    final candidates = gallery.catalog
        .where(
          (a) =>
              a.id != widget.art.id &&
              !gallery.isCompleted(a.id) &&
              gallery.isUnlocked(a, settings.isProUser),
        )
        .toList();
    if (candidates.isEmpty) {
      _showInfoSnack('You have completed everything — amazing!');
      return;
    }
    final next = candidates.firstWhere(
      (a) => a.category == widget.art.category,
      orElse: () => candidates.first,
    );
    // pushReplacement bypasses PopScope, so cover this exit path too.
    _maybeShowExitInterstitial();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ColoringScreen(art: next)),
    );
  }

  Widget _buildCompletionBar(ColoringProvider provider) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration_rounded,
                        color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _completionStats(provider),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
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
              _CompletionAction(
                icon: Icons.skip_next_rounded,
                label: 'Next',
                onTap: _openNextArt,
              ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One-line celebration summary, e.g. "248 cells · 8 colors · 12 min".
  String _completionStats(ColoringProvider provider) {
    final cells = provider.filledCellCount;
    final colors = widget.art.colorCount;
    final mins = DateTime.now().difference(_sessionStart).inMinutes;
    final timePart = mins < 1 ? 'under a min' : '$mins min';
    return '$cells cells · $colors colors · $timePart';
  }

  Future<void> _sharePng(ColoringProvider provider) async {
    final storageService = context.read<LocalStorageService>();
    final screenshotService = ScreenshotService(storageService);
    final pngBytes = await screenshotService.captureAsPng(_repaintKey);
    if (pngBytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pixely_${widget.art.id}.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'image/png'),
    ], text: 'I just finished "${widget.art.name}" in Pixely! 🎨');
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
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/gif'),
      ], text: 'Watch me paint "${widget.art.name}" in Pixely! 🎨');
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

  Widget _buildTopBar(
    BuildContext context,
    ColoringProvider provider,
    bool isComplete,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppStyle.glassmorphism(context),
      child: Row(
        children: [
          GestureDetector(
            // The PopScope around the Scaffold handles the exit interstitial
            // for both this button and the system back gesture.
            onTap: () => Navigator.pop(context),
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
                            color:
                                Theme.of(context).brightness == Brightness.light
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
          // Large grids fit the screen with tiny cells; allow zooming until a
          // cell is ~28px so every artwork stays comfortably tappable.
          maxScale: max(4.0, 28.0 / _cellSize),
          child: Center(
            // The boundary wraps only the grid so PNG exports are cropped to
            // the artwork, not the whole viewport.
            child: RepaintBoundary(
              key: _repaintKey,
              child: PixelGrid(
                provider: provider,
                cellSize: _cellSize,
                brushSize: provider.brushSize,
                isEraseMode: provider.isEraseMode,
                colorblindMode: settings.colorblindMode,
                gridFade: _gridFadeController,
                transform: _transformController,
                onCellTap: (row, col) => provider.tryFillCell(row, col),
                onCellLongPress: (row, col) {
                  _showColorPreview(context, provider, row, col);
                },
                onCellDragStart: () {
                  if (!provider.isMagicWandMode) provider.beginStroke();
                },
                onCellDrag: provider.strokeFill,
                onCellDragEnd: provider.endStroke,
                onCellDragCancel: provider.cancelStroke,
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
          // The coloring screen is where users spend their time — the banner
          // lives here for free users.
          if (!settings.isProUser)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: AdBanner(),
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
    _animateZoomTo(
      Matrix4.identity()
        ..translateByDouble(
          _viewerSize.width / 2 - scale * cx,
          _viewerSize.height / 2 - scale * cy,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
    );
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
                onFailed: () => _showInfoSnack(
                  'No ad available right now — try again later.',
                ),
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

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withAlpha(220)
              : Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppStyle.primary),
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
