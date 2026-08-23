import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_config.dart';
import '../../config/flavor.dart';
import '../../config/app_constants.dart';
import '../../data/models/pixel_art.dart';
import '../../data/models/split_art.dart';
import '../../data/models/user_artwork.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import 'part_selection_screen.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/iap_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/remote_config_service.dart';
import '../../data/services/review_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../data/services/timelapse_service.dart';
import '../../data/services/sound_service.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/widgets/ad_banner.dart';
import '../../ui/widgets/pixel_grid.dart';
import '../../ui/widgets/number_palette.dart';
import '../../ui/widgets/number_toolbar.dart';
import '../../ui/widgets/confetti_overlay.dart';
import '../../ui/widgets/next_cell_pulse.dart';
import '../../ui/widgets/coin_fly.dart';
import '../../ui/widgets/fill_effects_overlay.dart';
import '../../ui/widgets/fill_grow_controller.dart';
import '../../ui/widgets/rolling_count.dart';
import '../../ui/widgets/transitions.dart';

class ColoringScreen extends StatefulWidget {
  final PixelArt art;

  const ColoringScreen({super.key, required this.art});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  double _cellSize = AppConfig.defaultCellSize;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey<FillEffectsOverlayState> _fxKey = GlobalKey();
  // Per-cell "grow in" animation for tapped cells (strokes snap for perf).
  late final FillGrowController _growController = FillGrowController(
    widget.art.gridWidth,
  );
  late final AnimationController _growTicker;
  // Last cell painted (for the section-complete burst) and the highest combo
  // callout already shown this streak (so "Combo xN!" fires once per threshold).
  int _lastFillRow = 0;
  int _lastFillCol = 0;
  int _comboThresholdShown = 0;
  late AnimationController _confettiController;
  late AnimationController _replayController;
  late AnimationController _gridFadeController;
  late AnimationController _zoomAnimController;
  // Section-complete shimmer sweep across the gem board (shader-driven).
  // Idles at 1.0 (= inactive in the shader); forward(from: 0) runs one sweep.
  late AnimationController _shimmerController;
  // Staged entrance for the completion HUD: scrim → card → trophy → content.
  // Idles at 1.0 (fully shown); forward(from: 0) plays the entrance.
  late AnimationController _hudController;
  Matrix4Tween? _zoomTween;
  List<(int, int)> _replayActions = [];
  int _replayIndex = 0;
  double _replaySpeed = 1.0;
  List<List<int>>? _savedGridState;
  bool _wasComplete = false;
  bool _sharingGif = false;
  // Completion HUD ("level complete" dialog). Starts dismissed so reopening an
  // already-finished artwork shows the artwork (with a reopen button) rather
  // than popping the dialog; a fresh completion flips it open.
  bool _hudDismissed = true;
  // Diamonds awarded for finishing this artwork (0 if it had already paid out);
  // shown in the completion HUD.
  int _lastDiamondAward = 0;
  // True once the player has watched an ad to double this completion's reward,
  // so the offer is shown only once per finish.
  bool _rewardDoubled = false;
  LevelUpResult? _lastLevelUp;
  ColoringProvider? _coloringProvider;
  AppSettingsProvider? _settings;
  AdService? _adService;
  Size _viewerSize = Size.zero;
  // Toggled per gesture: a single-finger swipe that begins over a non-selected
  // cell pans the canvas; otherwise the finger paints (swipe-to-fill).
  final ValueNotifier<bool> _canvasPanNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Offset> _tiltNotifier = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _smoothTiltX = 0.0;
  double _smoothTiltY = 0.0;
  final DateTime _sessionStart = DateTime.now();

  // Coin bursts fly to the top bar's diamond chip, which pulses on arrival.
  final GlobalKey _diamondChipKey = GlobalKey();
  bool _diamondChipPulse = false;

  void _pulseDiamondChip() {
    if (!mounted) return;
    setState(() => _diamondChipPulse = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _diamondChipPulse = false);
    });
  }

  /// A coin burst that arcs into the diamond chip and pulses it on arrival.
  void _coinBurstToChip() {
    showCoinBurst(
      context,
      target: centerOfKey(_diamondChipKey),
      onArrive: _pulseDiamondChip,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The tilt stream has no visible effect while the app is backgrounded;
    // pausing it stops sensor wakeups (and the repaints they schedule).
    if (state == AppLifecycleState.resumed) {
      if (_accelerometerSubscription?.isPaused ?? false) {
        _accelerometerSubscription?.resume();
      }
    } else if (!(_accelerometerSubscription?.isPaused ?? true)) {
      _accelerometerSubscription?.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _adjustCellSize();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tilt only drives the gem/diamond flavor's specular highlight. On flat
    // flavors the sensor stream would repaint the whole grid for no visible
    // change, so only subscribe when a gem flavor is active.
    if (FlavorConfig.current.cellStyle == CellRenderStyle.gem) {
      try {
        _accelerometerSubscription = accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((AccelerometerEvent event) {
          if (!mounted) return;
          final normX = (event.x / 9.8).clamp(-1.0, 1.0);
          final normY = (event.y / 9.8).clamp(-1.0, 1.0);
          _smoothTiltX = _smoothTiltX * 0.8 + normX * 0.2;
          _smoothTiltY = _smoothTiltY * 0.8 + normY * 0.2;
          // Dead-zone: don't publish sub-perceptual jitter, so a grid held
          // still stops repainting instead of chasing sensor noise every tick.
          final prev = _tiltNotifier.value;
          if ((_smoothTiltX - prev.dx).abs() < 0.01 &&
              (_smoothTiltY - prev.dy).abs() < 0.01) {
            return;
          }
          _tiltNotifier.value = Offset(_smoothTiltX, _smoothTiltY);
        });
      } catch (e) {
        debugPrint('Accelerometer sensors not supported: $e');
      }
    }
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _confettiController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final provider = _coloringProvider;
        if (provider != null &&
            provider.currentArt?.id == widget.art.id &&
            provider.isComplete &&
            _hudDismissed) {
          setState(() {
            _hudDismissed = false;
          });
          _hudController.forward(from: 0);
        }
      }
    });
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );
    _hudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1.0,
    );
    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _replayController.addListener(_onReplayTick);
    _replayController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishReplay();
    });
    // Drives the per-cell grow-in repaint; repeats only while cells animate.
    _growTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        _growController.handleTick(DateTime.now().millisecondsSinceEpoch);
        if (_growController.isEmpty) _growTicker.stop();
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
              curve: Curves.easeInOut,
            ),
          );
        });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ColoringProvider>();
      // loadArt awaits any save still encoding on its worker isolate before
      // reading storage (quick exit-and-reopen must not restore stale
      // progress); everything below reads the freshly loaded state.
      await provider.loadArt(widget.art);
      if (!mounted) return;
      _adjustCellSize();
      _transformController.value = Matrix4.identity();
      // Clear any carry-over from the previously opened artwork.
      _confettiController.reset();
      _wasComplete = provider.isComplete;
      _gridFadeController.value = _wasComplete ? 1.0 : 0.0;
      _settings = context.read<AppSettingsProvider>()
        ..addListener(_onSettingsChanged);
      _adService = context.read<AdService>();
      // Preload the session-exit interstitial and the "next artwork"
      // rewarded interstitial; the capping logic decides later what shows.
      if (!(_settings?.isProUser ?? false)) {
        _adService!
          ..loadInterstitialAd()
          ..preloadRewardedInterstitial();
      }
      final soundService = context.read<SoundService>();
      _coloringProvider = provider
        ..addListener(_onProviderChanged)
        ..onCellFilledCorrectly = () {
          if (_settings?.soundsEnabled ?? true) {
            if (_settings?.soundType == 'bubble_pop') {
              soundService.playBubblePop();
            } else {
              soundService.playLightClick();
            }
          }
        }
        ..onSectionCompleted = () {
          if (_settings?.hapticsEnabled ?? true) {
            _playSectionCompletedHaptic();
          }
          // Celebrate a finished color with a bigger sparkle at the last cell
          // and one shimmer sweep across all placed gems.
          if (_settings?.fillEffectsEnabled ?? true) {
            final color =
                provider.cellFillColor(_lastFillRow, _lastFillCol) ??
                Colors.amber;
            _fxKey.currentState?.spawnBurst(_lastFillRow, _lastFillCol, color);
            _shimmerController.forward(from: 0);
          }
        }
        ..onCellFilledAt = _onCellFilledAt
        ..onWrongTap = (row, col) {
          // Gentle "not this one": shake + soft thud (haptic fires in the
          // provider alongside the fill haptics).
          if (_settings?.fillEffectsEnabled ?? true) {
            _fxKey.currentState?.spawnWrong(row, col);
          }
          if (_settings?.soundsEnabled ?? true) {
            soundService.playWrongTap();
          }
        }
        ..onBombExploded = (row, col) {
          if (_settings?.fillEffectsEnabled ?? true) {
            final color = provider.cellFillColor(row, col) ?? const Color(0xFFFF5252);
            _fxKey.currentState?.spawnBombExplosion(row, col, color);
          }
          if (_settings?.soundsEnabled ?? true) {
            soundService.playComboChime(rate: 0.85);
          }
          if (_settings?.hapticsEnabled ?? true) {
            provider.bombHaptic();
          }
        };
      _maybeShowLongPressTip();
      // Fire enter event after art is fully loaded so progress_pct is accurate.
      AnalyticsService().logArtworkEntered(
        artId: widget.art.id,
        category: widget.art.category,
        title: widget.art.name,
        flavor: currentFlavor.name,
        existingProgressPct: (provider.progress * 100).round(),
      );
    });
  }

  /// Spawns a joyful flourish at a just-filled cell. Single taps/hints get the
  /// full effect; mid-stroke fills get a throttled lighter version. Combo
  /// callouts fire once each time the streak crosses a threshold.
  void _onCellFilledAt(int row, int col) {
    if (!(_settings?.fillEffectsEnabled ?? true)) return;
    final provider = _coloringProvider;
    if (provider == null) return;
    _lastFillRow = row;
    _lastFillCol = col;
    final color = provider.cellFillColor(row, col) ?? AppStyle.primary;
    final combo = provider.consecutiveFills;
    final stroking = provider.isStroking;
    // The grid animates every fill itself now (gem: shader settle/glint;
    // flat: grow + afterglow), so the overlay never adds its own cell pop —
    // it would be double feedback. Strokes keep the throttled sparkle trail.
    _fxKey.currentState?.spawn(
      row,
      col,
      color,
      full: !stroking,
      combo: combo,
      pop: false,
    );

    // Register every fill's timestamp: it drives the tap grow and afterglow
    // on the flat grid, and the shader's settle/glint/wave-stagger in gem
    // mode. Stroke registration is safe now — stroke rebuilds are coalesced
    // per frame and the registry is capped, unlike the per-cell rebuild storm
    // that originally forced strokes to snap.
    _growController.add(row, col, DateTime.now().millisecondsSinceEpoch);
    if (!_growTicker.isAnimating) _growTicker.repeat();

    // Combo callouts: fire once per crossed threshold; reset when the streak
    // drops back below what we last announced.
    if (combo < _comboThresholdShown) _comboThresholdShown = 0;
    for (final threshold in AppConstants.comboThresholds) {
      if (combo >= threshold && threshold > _comboThresholdShown) {
        _comboThresholdShown = threshold;
        _fxKey.currentState?.spawnComboText(row, col, combo);
        // Escalating chime + buzz: each tier one step higher/stronger.
        final tier = AppConstants.comboThresholds.indexOf(threshold);
        if (_settings?.soundsEnabled ?? true) {
          context
              .read<SoundService>()
              .playComboChime(rate: 1.0 + tier * 0.12);
        }
        if (_settings?.hapticsEnabled ?? true) {
          provider.comboHaptic(tier);
        }
      }
    }
  }

  /// Reacts to provider events: achievement unlocks and the
  /// incomplete -> complete transition (grid fade + interstitial preload).
  void _onProviderChanged() {
    final provider = _coloringProvider;
    if (provider == null || !mounted) return;

    final settings = context.read<AppSettingsProvider>();

    final unlocked = provider.lastUnlockedAchievement;
    if (unlocked != null) {
      provider.clearLastUnlockedAchievement();
      // Award achievement diamonds silently without showing a popup dialog.
      settings.addDiamonds(AppConstants.diamondsPerAchievement);
    }

    _checkMilestones(provider, settings);

    if (provider.isComplete && !_wasComplete) {
      _wasComplete = true;
      if (settings.hapticsEnabled) {
        provider.victoryHaptic();
      }
      _saveArtwork(context, provider);

      void startCelebration() {
        if (!mounted) return;
        _gridFadeController.forward();
        // Pay out the diamond reward (once per artwork) and surface the
        // "level complete" HUD after the confetti gets going.
        final gallery = context.read<GalleryProvider>();
        final isDaily = gallery.dailyArt?.id == widget.art.id;
        final awarded = settings.awardCompletionDiamonds(
          widget.art.id,
          isDaily: isDaily,
        );
        // Award XP for the finished piece and track lifetime cells; a level-up
        // celebrates after the completion HUD appears.
        final cells = provider.filledCellCount;
        settings.addLifetimeCells(cells);
        final levelUp = settings.addXp(
          cells * AppConstants.xpPerCell + AppConstants.xpPerCompletion,
        );
        if (levelUp.leveledUp) {
          _lastLevelUp = levelUp;
        } else {
          _lastLevelUp = null;
        }
        setState(() {
          _lastDiamondAward = awarded;
          _rewardDoubled = false;
          _hudDismissed = true;
        });
        if (_settings?.soundsEnabled ?? true) {
          context.read<SoundService>().playComboChime(rate: 1.25);
        }
        _confettiController.forward(from: 0);
      }

      // First ensure artwork is shown completely on screen (fitted), then start celebration animation.
      final isZoomed = !_transformController.value.isIdentity();
      if (isZoomed) {
        _animateZoomTo(Matrix4.identity(), onComplete: startCelebration);
      } else {
        startCelebration();
      }
    } else if (!provider.isComplete && _wasComplete) {
      _wasComplete = false;
      _gridFadeController.value = 0;
    }
  }

  /// Grants the mid-progress milestone gifts (30% → a bomb, 65% → diamonds) the
  /// first time each threshold is reached. Rewards land with lightweight,
  /// non-blocking feedback (a brief snackbar, plus a coin burst for diamonds) —
  /// no modal dialog, so coloring is never interrupted. 100% is celebrated by
  /// the completion HUD.
  void _checkMilestones(ColoringProvider provider, AppSettingsProvider settings) {
    if (provider.claimMilestone(30)) {
      provider.addBombs(AppConstants.milestone30Bomb);
      AnalyticsService().logMilestoneClaimed(artId: widget.art.id, percent: 30, title: widget.art.name);
      // Same visual payoff class as the 65% milestone — a burst at the last
      // painted cell — so the first milestone doesn't feel like a mere toast.
      _fxKey.currentState?.spawnBurst(
        _lastFillRow,
        _lastFillCol,
        const Color(0xFFFF9D2E),
      );
      _showInfoSnack('Milestone reached · +${AppConstants.milestone30Bomb} Bomb');
    }
    if (provider.claimMilestone(65)) {
      settings.addDiamonds(AppConstants.milestone65Diamonds);
      AnalyticsService().logMilestoneClaimed(artId: widget.art.id, percent: 65, title: widget.art.name);
      _coinBurstToChip();
      _showInfoSnack('Milestone reached · +${AppConstants.milestone65Diamonds} 💎');
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

  int get _sessionProgressPct =>
      ((_coloringProvider?.progress ?? 0) * 100).round();

  /// Leaving a coloring session is the one interruption point users accept.
  /// AdService applies the caps (min session length or progress, cooldown,
  /// session/day ceilings, first session, recent rewarded); this just reports
  /// the session.
  void _maybeShowExitInterstitial() {
    final adService = _adService;
    if (adService == null || (_settings?.isProUser ?? true)) return;
    final session = DateTime.now().difference(_sessionStart);
    if (adService.canShowSessionInterstitial(
      session,
      progressPct: _sessionProgressPct,
    )) {
      adService.showInterstitialAd();
    }
  }

  /// "Next artwork" ad slot: prefer a rewarded interstitial (+diamonds,
  /// opt-out, higher eCPM) over the plain exit interstitial — it converts the
  /// tax into a gift. Falls back to the interstitial when no rewarded
  /// interstitial is configured/loaded; both share the same pacing pool.
  void _maybeShowNextArtAd() {
    final adService = _adService;
    final settings = _settings;
    if (adService == null || (settings?.isProUser ?? true)) return;
    final session = DateTime.now().difference(_sessionStart);
    if (adService.canShowRewardedInterstitial(
      session,
      progressPct: _sessionProgressPct,
    )) {
      final amount = RemoteConfigService().nextArtRewardDiamonds;
      adService.showRewardedInterstitialAd(
        placement: 'next_art',
        onRewarded: () => settings?.addDiamonds(amount),
      );
    } else {
      _maybeShowExitInterstitial();
    }
  }

  void _adjustCellSize() {
    final screenSize = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final availableWidth = screenSize.width - 32;
    // Top bar (~64) + toolbar/palette/banner (~250).
    final availableHeight = screenSize.height - pad.bottom - 250;
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
    final provider = _coloringProvider;
    // Only detach the shared-provider callbacks if this screen still owns it.
    // "Next Artwork" uses pushReplacement, which rebinds these to the new
    // screen BEFORE this old one is disposed — clearing them unconditionally
    // would kill the next artwork's fill effects / sound / section haptics.
    // (The per-instance listener is always safe to remove.)
    if (provider != null && provider.currentArt?.id == widget.art.id) {
      final sessionSeconds = DateTime.now().difference(_sessionStart).inSeconds;
      final progressPct = (provider.progress * 100).round();
      // Core retention signal: how long the session ran, how far it got,
      // and whether the artwork was finished.
      AnalyticsService().logSessionEnd(
        artId: widget.art.id,
        title: widget.art.name,
        seconds: sessionSeconds,
        progressPct: progressPct,
        completed: provider.isComplete,
        flavor: currentFlavor.name,
        exitReason: provider.isComplete ? 'completed' : 'back',
      );
      AnalyticsService().logArtworkExited(
        artId: widget.art.id,
        title: widget.art.name,
        seconds: sessionSeconds,
        progressPct: progressPct,
        exitReason: provider.isComplete ? 'completed' : 'back',
        flavor: currentFlavor.name,
      );
      provider.onCellFilledCorrectly = null;
      provider.onSectionCompleted = null;
      provider.onCellFilledAt = null;
      provider.onWrongTap = null;
      provider.onBombExploded = null;
    }
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
    _shimmerController.dispose();
    _hudController.dispose();
    _growTicker.dispose();
    _growController.dispose();
    _canvasPanNotifier.dispose();
    _accelerometerSubscription?.cancel();
    _tiltNotifier.dispose();
    _MiniMapPainter.releaseCache();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _playSectionCompletedHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  void _animateZoomTo(Matrix4 target, {VoidCallback? onComplete}) {
    _zoomTween = Matrix4Tween(
      begin: _transformController.value.clone(),
      end: target,
    );
    if (onComplete != null) {
      late AnimationStatusListener listener;
      listener = (status) {
        if (status == AnimationStatus.completed) {
          _zoomAnimController.removeStatusListener(listener);
          onComplete();
        }
      };
      _zoomAnimController.addStatusListener(listener);
    }
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
    // Rebuild scoping: the root deliberately does NOT listen to the coloring
    // provider — every fill used to rebuild the entire screen (toolbar,
    // palette list, banner, viewer shell) per tap. Instead, each region that
    // genuinely changes per fill wraps itself in a scoped ListenableBuilder,
    // and the static shells (gradient, InteractiveViewer, effect overlays,
    // confetti) are built once. Settings changes are rare, so a plain watch
    // is fine for them.
    final provider = context.read<ColoringProvider>();
    final settings = context.watch<AppSettingsProvider>();

    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _saveArtwork(context, provider);
          _maybeShowExitInterstitial();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF14141F), const Color(0xFF0F0F16)]
                  : [const Color(0xFFF9F9FB), const Color(0xFFECEFF1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              _buildGrid(provider, settings),

              // Breathing highlight on the next fillable cell — its own tiny
              // layer so the animation never repaints the grid.
              ListenableBuilder(
                listenable: provider,
                builder: (context, _) {
                  final show = provider.currentArt?.id == widget.art.id &&
                      !provider.isComplete &&
                      !provider.isEraseMode;
                  return Positioned.fill(
                    child: NextCellPulse(
                      transformController: _transformController,
                      cellSize: _cellSize,
                      viewerSize: _viewerSize,
                      gridWidth: widget.art.gridWidth,
                      gridHeight: widget.art.gridHeight,
                      cell: show ? provider.nextFillable : null,
                    ),
                  );
                },
              ),

              // Joyful fill effects, layered directly above the grid and
              // glued to cells via the shared transform.
              if (settings.fillEffectsEnabled)
                Positioned.fill(
                  child: FillEffectsOverlay(
                    key: _fxKey,
                    transformController: _transformController,
                    cellSize: _cellSize,
                    viewerSize: _viewerSize,
                    gridWidth: widget.art.gridWidth,
                    gridHeight: widget.art.gridHeight,
                    tiltNotifier: _tiltNotifier,
                    particleStyle: settings.particleStyle,
                  ),
                ),

              // 1. Top Bar (Overlay)
              Positioned(
                top: statusBarHeight + 8,
                left: 16,
                right: 16,
                child: ListenableBuilder(
                  listenable: provider,
                  builder: (context, _) {
                    final isComplete =
                        provider.currentArt?.id == widget.art.id &&
                            provider.isComplete;
                    return _buildTopBar(context, provider, isComplete);
                  },
                ),
              ),

              // 2. Mini Preview in Top Left
              Positioned(
                top: statusBarHeight + 116,
                left: 12,
                child: ListenableBuilder(
                  listenable: provider,
                  builder: (context, _) {
                    if (provider.currentArt?.id != widget.art.id) {
                      return const SizedBox.shrink();
                    }
                    return _buildMiniMap(provider, isDark);
                  },
                ),
              ),

              ListenableBuilder(
                listenable: provider,
                builder: (context, _) => _buildModePill(provider),
              ),
              ConfettiOverlay(
                animation: _confettiController,
                seed: widget.art.id.hashCode,
              ),

              // 4. Bottom Section: the toolbar/palette/banner while there's
              // still something to color. Once complete it gives way to the
              // completion HUD (and a reopen button when that's dismissed).
              ListenableBuilder(
                listenable: provider,
                builder: (context, _) {
                  // The provider is app-scoped and loadArt runs post-frame, so
                  // the first frame still carries the PREVIOUS artwork's
                  // state. Never let stale completion trigger confetti or the
                  // completion UI for this art.
                  final isComplete =
                      provider.currentArt?.id == widget.art.id &&
                          provider.isComplete;
                  if (_replayController.isAnimating || _replayActions.isNotEmpty) {
                    return _buildReplayControls();
                  }
                  if (!isComplete) {
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomSection(context, provider, settings),
                    );
                  }
                  if (_confettiController.isAnimating) {
                    return const SizedBox.shrink();
                  }
                  return _hudDismissed
                      ? _buildReopenOptionsButton()
                      : _buildCompletionHud(provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMap(ColoringProvider provider, bool isDark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withAlpha(120) : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        // The aspect box keeps non-square (portrait/landscape) artworks from
        // stretching to fill the square minimap chrome.
        child: Center(
          child: AspectRatio(
            aspectRatio: widget.art.gridWidth / widget.art.gridHeight,
            // Two layers so a pinch/pan frame repaints only the viewport
            // rectangle: the base map (every cell) repaints only when fill
            // state actually changes (fillVersion), behind its own
            // RepaintBoundary.
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _MiniMapPainter(
                      art: widget.art,
                      filledGrid: provider.filledGrid,
                      filledColors: provider.filledColors,
                      fillVersion: provider.fillVersion,
                      changesSince: provider.changesSince,
                    ),
                  ),
                ),
                ValueListenableBuilder<Matrix4>(
                  valueListenable: _transformController,
                  builder: (context, transform, _) {
                    final viewportRect = _calculateViewportRect(
                      transform,
                      _viewerSize,
                      _cellSize,
                      widget.art,
                    );
                    return CustomPaint(
                      painter:
                          _MiniMapViewportPainter(viewportRect: viewportRect),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Offers a rewarded ad that doubles this completion's diamond payout (adds
  /// the base award a second time). Fires once per finish.
  void _watchAdToDouble(int baseAward) {
    final adService = context.read<AdService>();
    final settings = context.read<AppSettingsProvider>();
    void grant() {
      settings.addDiamonds(baseAward);
      if (mounted) setState(() => _rewardDoubled = true);
      _coinBurstToChip();
      _showInfoSnack('Reward doubled! +$baseAward diamonds');
    }

    if (AppConfig.disableAds || !AppConfig.showAds) {
      grant(); // Simulated ad in dev/no-ads builds.
      return;
    }
    adService.showRewardedAd(
      placement: 'double_reward',
      onRewarded: grant,
      onUnavailable: () =>
          _showInfoSnack('No ad available right now — try again later.'),
    );
  }

  /// Clear feedback that a destructive/special mode is active — the toolbar
  /// label alone is easy to miss.
  Widget _buildModePill(ColoringProvider provider) {
    final active = provider.isEraseMode ||
        provider.isMagicWandMode ||
        provider.isBombMode;
    final Color color;
    final IconData icon;
    final String text;
    if (provider.isEraseMode) {
      color = const Color(0xFFFF6B6B);
      icon = Icons.cleaning_services;
      text = 'Eraser on';
    } else if (provider.isBombMode) {
      color = Colors.black87;
      icon = Icons.bolt;
      text = 'Bomb mode: tap an area to explode';
    } else {
      color = const Color(0xFF9C27B0);
      icon = Icons.auto_fix_high_rounded;
      text = 'Magic wand: tap an area';
    }
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Positioned(
      top: statusBarHeight + 104,
      left: 0,
      right: 0,
      child: Center(
        // Pop in/out (and morph between modes) instead of snapping.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: !active
              ? const SizedBox.shrink(key: ValueKey('pill-off'))
              : Container(
                  key: ValueKey(text),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        text,
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
      ),
    );
  }

  /// True when this canvas holds one tile of a split artwork rather than a
  /// standalone piece.
  bool get _isPart => SplitArt.isPartId(widget.art.id);

  /// Suggests another piece to color right after finishing one. For a split
  /// part that's the next unfinished sibling tile; when none remain, pop back
  /// to the part picker so it can play the merge reveal.
  void _openNextArt() {
    final gallery = context.read<GalleryProvider>();
    if (_isPart) {
      final parentId = SplitArt.parentIdOf(widget.art.id);
      final partIndex = SplitArt.partIndexOf(widget.art.id) ?? 0;
      PixelArt? parent;
      for (final a in gallery.catalog) {
        if (a.id == parentId) {
          parent = a;
          break;
        }
      }
      // validSplit mirrors the guard every other partOf call site has —
      // partOf's own checks are asserts, which compile out in release.
      if (parent != null && SplitArt.validSplit(parent)) {
        for (int step = 1; step < parent.partCount; step++) {
          final i = (partIndex + step) % parent.partCount;
          if (gallery.partProgressPercent(parent, i) < 100) {
            _maybeShowNextArtAd();
            Navigator.pushReplacement(
              context,
              fadeThroughRoute(
                ColoringScreen(art: SplitArt.partOf(parent, i)),
                name: 'coloring',
              ),
            );
            return;
          }
        }
      }
      Navigator.pop(context);
      return;
    }
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
    _maybeShowNextArtAd();
    // Keep remote artworks playable even if their Firestore doc vanishes.
    gallery.noteArtworkOpened(next);
    if (next.isSplit && SplitArt.validSplit(next)) {
      Navigator.pushReplacement(
        context,
        fadeThroughRoute(
          PartSelectionScreen(parent: next),
          name: 'part_selection',
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      fadeThroughRoute(ColoringScreen(art: next), name: 'coloring'),
    );
  }

  /// The "level complete" HUD: a centered card over a dimmed scrim with the
  /// celebration summary plus Replay / Share / Share GIF / Next actions.
  /// A slice of the HUD entrance timeline.
  Animation<double> _hudStage(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) {
    return CurvedAnimation(
      parent: _hudController,
      curve: Interval(begin, end, curve: curve),
    );
  }

  /// Fade + rise for HUD content rows, staggered by [slot].
  Widget _hudReveal(int slot, Widget child) {
    final anim = _hudStage(
      (0.35 + slot * 0.07).clamp(0.0, 0.9),
      (0.60 + slot * 0.07).clamp(0.0, 1.0),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Widget _buildCompletionHud(ColoringProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;
    return Positioned.fill(
      // Staged entrance: the scrim settles first, the card scales in over it,
      // then the trophy pops and the content rows rise one after another.
      child: FadeTransition(
        opacity: _hudStage(0, 0.3, Curves.easeOut),
        child: Container(
          color: Colors.black.withAlpha(150),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0)
                      .animate(_hudStage(0.1, 0.5, Curves.easeOutBack)),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [const Color(0xFF2A2440), const Color(0xFF1B1830)]
                                : [Colors.white, const Color(0xFFF3F0FF)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppStyle.primary.withAlpha(80),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.3, end: 1.0)
                                  .animate(_hudStage(0.3, 0.85, Curves.elasticOut)),
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF9D2E).withAlpha(140),
                                      blurRadius: 24,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events_rounded,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Masterpiece Complete!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.art.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: subColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _hudReveal(
                              0,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppStyle.primary.withAlpha(isDark ? 45 : 22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.celebration_rounded,
                                      color: AppStyle.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _completionStats(provider),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: titleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Integrated Level Up Banner (if player leveled up)
                            if (_lastLevelUp != null) ...[
                              const SizedBox(height: 12),
                              _hudReveal(
                                1,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB14CFF), Color(0xFF7A2BE2)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7A2BE2).withAlpha(120),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(50),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.military_tech_rounded,
                                          color: Color(0xFFFFD24C),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'LEVEL UP!',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFFFE08A),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          Text(
                                            'Reached Level ${_lastLevelUp!.newLevel} 🎉',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_lastLevelUp!.diamondsAwarded > 0) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(60),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '+${_lastLevelUp!.diamondsAwarded} 💎',
                                            style: const TextStyle(
                                              color: Color(0xFFFFD24C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // Catchy Diamond Reward Card
                            if (_lastDiamondAward > 0) ...[
                              const SizedBox(height: 12),
                              _hudReveal(
                                2,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isDark
                                        ? const LinearGradient(
                                            colors: [Color(0xFF3D2C00), Color(0xFF593E00)],
                                          )
                                        : const LinearGradient(
                                            colors: [Color(0xFFFFF8E7), Color(0xFFFFECB3)],
                                          ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFFFB300),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF9D2E).withAlpha(90),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.diamond_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Reward Earned!',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFFFD24C) : const Color(0xFFB76E00),
                                            ),
                                          ),
                                          Text(
                                            '+$_lastDiamondAward Diamonds',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.white : const Color(0xFF4A2C00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // Rewarded-ad offer to double payout (non-Pro, once)
                            if (_lastDiamondAward > 0 &&
                                !_rewardDoubled &&
                                !context.read<AppSettingsProvider>().isProUser) ...[
                              const SizedBox(height: 12),
                              _hudReveal(
                                3,
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _watchAdToDouble(_lastDiamondAward),
                                    icon: const Icon(Icons.play_circle_fill_rounded,
                                        size: 20),
                                    label: const Text('Watch ad → 2× diamonds'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF9D2E),
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shadowColor: const Color(0xFFFF9D2E).withAlpha(100),
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Colorful Action Buttons (Replay, Share, Share GIF)
                            _hudReveal(
                              4,
                              Row(
                                children: [
                                  Expanded(
                                    child: _HudAction(
                                      icon: Icons.replay_rounded,
                                      label: 'Replay',
                                      color: const Color(0xFF6C5CE7),
                                      onTap: () => _startTimeLapse(provider),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _HudAction(
                                      icon: Icons.image_rounded,
                                      label: 'Share',
                                      color: const Color(0xFF00CEC9),
                                      onTap: () => _sharePng(provider),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _HudAction(
                                      icon: Icons.movie_rounded,
                                      label: _sharingGif ? 'Rendering…' : 'Share GIF',
                                      color: const Color(0xFFE84393),
                                      onTap: _sharingGif
                                          ? null
                                          : () => _shareTimelapse(provider),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Next Artwork Button
                            _hudReveal(
                              5,
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openNextArt,
                                  icon: const Icon(Icons.skip_next_rounded, size: 22),
                                  label: Text(_isPart ? 'Next Part' : 'Next Artwork'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppStyle.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: AppStyle.primary.withAlpha(120),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Top Right Cross (Close / X) Button
                      Positioned(
                        top: 10,
                        right: 38,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() => _hudDismissed = true);
                              ReviewService().maybeRequestReview(
                                storage: context.read<LocalStorageService>(),
                                completedCount: context
                                    .read<GalleryProvider>()
                                    .completedIds
                                    .length,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withAlpha(30)
                                    : Colors.black.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating button shown once the HUD is dismissed so the completion options
  /// remain one tap away while the user admires the finished artwork.
  Widget _buildReopenOptionsButton() {
    return Positioned(
      right: 16,
      bottom: 16 + MediaQuery.of(context).padding.bottom,
      child: FloatingActionButton.extended(
        onPressed: () {
          setState(() => _hudDismissed = false);
          _hudController.forward(from: 0);
        },
        backgroundColor: AppStyle.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.emoji_events_rounded),
        label: const Text('Options'),
      ),
    );
  }

  /// Opens the in-canvas shop: spend earned diamonds on hints and tools.
  void _showShop(ColoringProvider provider, AppSettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        // Rebuilds on each purchase so the balance and affordability update.
        return Consumer<AppSettingsProvider>(
          builder: (context, s, _) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shop',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Counts up/down to the new balance after a buy.
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  end: s.diamondsAvailable.toDouble(),
                                ),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                builder: (_, value, _) => Text(
                                  '${value.round()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.diamond_rounded,
                                color: Color(0xFFFF9D2E),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        'Spend diamonds earned by finishing artworks.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const Divider(height: 8),
                    if (!AppConfig.disableAds &&
                        AppConfig.showAds &&
                        RemoteConfigService().freeDiamondsEnabled)
                      _FreeDiamondsTile(
                        amount: RemoteConfigService().rewardedDiamondsAmount,
                        remaining: s.freeDiamondClaimsRemaining,
                        onWatch: () => _watchAdForFreeDiamonds(s),
                      ),
                    _ShopTile(
                      icon: Icons.lightbulb_rounded,
                      color: const Color(0xFFFFC107),
                      name: 'Hint',
                      desc: 'Reveal one correct cell',
                      cost: AppConstants.diamondCostHint,
                      canAfford: s.diamondsAvailable >= AppConstants.diamondCostHint,
                      onPurchase: () => _buyShopItem(
                        s,
                        AppConstants.diamondCostHint,
                        'Hint',
                        () => s.addHints(1),
                      ),
                    ),
                    _ShopTile(
                      icon: Icons.auto_fix_high_rounded,
                      color: const Color(0xFF9C27B0),
                      name: 'Magic Wand',
                      desc: 'Flood-fill a whole area',
                      cost: AppConstants.diamondCostWand,
                      canAfford: s.diamondsAvailable >= AppConstants.diamondCostWand,
                      onPurchase: () => _buyShopItem(
                        s,
                        AppConstants.diamondCostWand,
                        'Magic Wand',
                        () => provider.addMagicWands(1),
                      ),
                    ),
                    _ShopTile(
                      icon: Icons.bolt_rounded,
                      color: Colors.black87,
                      name: 'Bomb',
                      desc: 'Clear an area in one tap',
                      cost: AppConstants.diamondCostBomb,
                      canAfford: s.diamondsAvailable >= AppConstants.diamondCostBomb,
                      onPurchase: () => _buyShopItem(
                        s,
                        AppConstants.diamondCostBomb,
                        'Bomb',
                        () => provider.addBombs(1),
                      ),
                    ),
                    _ShopTile(
                      icon: Icons.brush_rounded,
                      color: const Color(0xFF03A9F4),
                      name: 'Brush',
                      desc: 'Paint multiple cells at once',
                      cost: AppConstants.diamondCostBrush,
                      canAfford: s.diamondsAvailable >= AppConstants.diamondCostBrush,
                      onPurchase: () => _buyShopItem(
                        s,
                        AppConstants.diamondCostBrush,
                        'Brush',
                        () => provider.addBrushes(1),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Watch a rewarded ad for a capped daily diamond payout (shop tile).
  void _watchAdForFreeDiamonds(AppSettingsProvider settings) {
    void grant() {
      final amount = settings.claimFreeDiamonds();
      if (amount <= 0) return;
      _coinBurstToChip();
      _showInfoSnack('+$amount diamonds!');
    }

    if (AppConfig.disableAds || !AppConfig.showAds) {
      grant(); // Simulated ad in dev/no-ads builds.
      return;
    }
    context.read<AdService>().showRewardedAd(
      placement: 'shop_free_diamonds',
      onRewarded: grant,
      onUnavailable: () =>
          _showInfoSnack('No ad available right now — try again later.'),
    );
  }

  /// Attempts a purchase: spends [cost] diamonds and runs [grant] on success.
  /// Returns true if it went through, letting the tile play its buy animation.
  bool _buyShopItem(
    AppSettingsProvider settings,
    int cost,
    String name,
    VoidCallback grant,
  ) {
    if (!settings.useDiamonds(cost)) return false;
    grant();
    HapticFeedback.mediumImpact();
    return true;
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
    try {
      final storageService = context.read<LocalStorageService>();
      final screenshotService = ScreenshotService(storageService);
      final pngBytes = await screenshotService.captureAsPng(_repaintKey);
      if (pngBytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pixely_${widget.art.id}.png');
      await file.writeAsBytes(pngBytes);
      AnalyticsService().logArtworkShared(
        artId: widget.art.id,
        format: 'png',
        title: widget.art.name,
        flavor: currentFlavor.name,
      );
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/png'),
      ], text: 'I just finished "${widget.art.name}" in ${FlavorConfig.current.appName}! 🎨');
    } catch (_) {
      // Full storage / no share handler must not crash the celebration HUD.
      _showInfoSnack('Could not share right now.');
    }
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
      AnalyticsService().logArtworkShared(
        artId: widget.art.id,
        format: 'gif',
        title: widget.art.name,
        flavor: currentFlavor.name,
      );
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/gif'),
      ], text: 'Watch me paint "${widget.art.name}" in ${FlavorConfig.current.appName}! 🎨');
    } catch (_) {
      // renderGif rethrows isolate failures (e.g. OOM on huge grids) and the
      // file/share steps can throw too; fail soft instead of crashing.
      _showInfoSnack('Could not render the time-lapse.');
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

  void _setReplaySpeed(double speed) {
    if (_replaySpeed == speed) return;
    final currentProgress = _replayController.value;
    _replaySpeed = speed;
    if (_replayActions.isNotEmpty) {
      final baseMs = max(1000, _replayActions.length * 30);
      final newMs = (baseMs / speed).round();
      _replayController.duration = Duration(milliseconds: newMs);
      if (_replayController.isAnimating) {
        _replayController.forward(from: currentProgress);
      }
    }
    if (mounted) setState(() {});
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
    final baseMs = max(1000, _replayActions.length * 30);
    _replayController.duration = Duration(
      milliseconds: (baseMs / _replaySpeed).round(),
    );
    AnalyticsService().logReplayWatched(artId: widget.art.id);
    _replayController.forward(from: 0);
    setState(() {});
  }

  Widget _buildReplayControls() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xEE1E1E2A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _replayController.isAnimating
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () {
                    if (_replayController.isAnimating) {
                      _replayController.stop();
                    } else {
                      _replayController.forward();
                    }
                    if (mounted) setState(() {});
                  },
                ),
                const Text(
                  'Replay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildSpeedChip(1.0, '1x'),
                const SizedBox(width: 6),
                _buildSpeedChip(2.0, '2x'),
                const SizedBox(width: 6),
                _buildSpeedChip(4.0, '4x'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () {
                    _replayController.stop();
                    _replayController.reset();
                    _finishReplay();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedChip(double speed, String label) {
    final isSelected = _replaySpeed == speed;
    return InkWell(
      onTap: () => _setReplaySpeed(speed),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppStyle.primary : Colors.white12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _onReplayTick() {
    if (_replayActions.isEmpty) return;
    final provider = context.read<ColoringProvider>();
    final target = (_replayController.value * _replayActions.length).floor();
    while (_replayIndex < target && _replayIndex < _replayActions.length) {
      final (r, c) = _replayActions[_replayIndex];
      provider.timeLapseStep(r, c);
      // A sparse sparkle trail keeps the replay lively without flooding the
      // effects pool (which caps at a few dozen live effects anyway).
      if (_replayIndex % 24 == 0 &&
          (_settings?.fillEffectsEnabled ?? true)) {
        final color = provider.cellFillColor(r, c) ?? AppStyle.primary;
        _fxKey.currentState?.spawn(r, c, color, full: false, pop: false);
      }
      _replayIndex++;
    }
  }

  void _finishReplay() {
    if (_savedGridState != null) {
      context.read<ColoringProvider>().restoreGridState(_savedGridState!);
      _savedGridState = null;
    }
    _replayActions = [];
    // Replay was launched from the HUD; close the show with one shimmer sweep
    // across the finished board, then bring the HUD back with its entrance.
    if (mounted) {
      _shimmerController.forward(from: 0);
      setState(() => _hudDismissed = false);
      _hudController.forward(from: 0);
    }
  }

  Widget _buildTopBar(
    BuildContext context,
    ColoringProvider provider,
    bool isComplete,
  ) {
    final settings = context.read<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      // BackdropFilter removed: a persistent real-time blur here re-rasterized
      // the whole backdrop every frame (major raster-thread cost). A near-opaque
      // solid panel gives the same legibility for almost no GPU cost.
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withAlpha(215) : Colors.white.withAlpha(236),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProgressGiftsBar(progress: provider.progress),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showAmbientControls(context, settings),
                    child: Icon(
                      settings.ambientTrack != 'none'
                          ? Icons.music_note_rounded
                          : Icons.music_off_rounded,
                      size: 20,
                      color: settings.ambientTrack != 'none'
                          ? AppStyle.primary
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _zoomBy(0),
                    child: Icon(
                      Icons.fit_screen_rounded,
                      size: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showShop(provider, settings),
                    child: AnimatedScale(
                      scale: _diamondChipPulse ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Container(
                      key: _diamondChipKey,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: Colors.indigoAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          RollingCount(
                            settings.diamondsAvailable,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.diamond_rounded,
                            color: Colors.orange,
                            size: 12,
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  void _showAmbientControls(BuildContext context, AppSettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<AppSettingsProvider>(
          builder: (ctx, settings, _) {
            final soundService = ctx.read<SoundService>();
            final tracks = [
              {'key': 'none', 'label': 'Off 🔇'},
              {'key': 'rain', 'label': 'Soft Rain 🌧️'},
              {'key': 'ocean', 'label': 'Gentle Waves 🌊'},
              {'key': 'zen', 'label': 'Zen Chimes 🧘'},
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ambient Soundscape',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tracks.map((t) {
                        final key = t['key']!;
                        final label = t['label']!;
                        final isSelected = settings.ambientTrack == key;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              settings.setAmbientTrack(key);
                              soundService.playAmbient(key);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    if (settings.ambientTrack != 'none') ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.volume_down, size: 20),
                          Expanded(
                            child: Slider(
                              value: settings.ambientVolume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) {
                                settings.setAmbientVolume(val);
                                soundService.setAmbientVolume(val);
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up, size: 20),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(ColoringProvider provider, AppSettingsProvider settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewerSize = Size(constraints.maxWidth, constraints.maxHeight);
        // Two fingers always pan and pinch-zoom. Single-finger panning is
        // turned on only for the duration of a swipe that began over a
        // non-selected cell; otherwise the finger paints (swipe-to-fill).
        return ValueListenableBuilder<bool>(
          valueListenable: _canvasPanNotifier,
          builder: (context, panEnabled, child) {
            return InteractiveViewer(
              transformationController: _transformController,
              panEnabled: panEnabled,
              minScale: 0.5,
              // Large grids fit the screen with tiny cells; allow zooming until a
              // cell is ~28px so every artwork stays comfortably tappable.
              maxScale: max(4.0, 28.0 / _cellSize),
              child: child!,
            );
          },
          child: Center(
            // The boundary wraps only the grid so PNG exports are cropped to
            // the artwork, not the whole viewport. Only this subtree listens
            // to the provider — a fill rebuilds the canvas widget, not the
            // viewer shell around it.
            child: RepaintBoundary(
              key: _repaintKey,
              child: ListenableBuilder(
                listenable: provider,
                builder: (context, _) {
                  // App-scoped provider: don't render the previous artwork's
                  // state before loadArt (post-frame) swaps it.
                  if (provider.currentArt?.id != widget.art.id) {
                    return Hero(
                      tag: 'art_canvas_${widget.art.id}',
                      child: SizedBox(
                        width: widget.art.gridWidth * _cellSize,
                        height: widget.art.gridHeight * _cellSize,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    );
                  }
                  return Hero(
                    tag: 'art_canvas_${widget.art.id}',
                    child: PixelGrid(
                      provider: provider,
                      cellSize: _cellSize,
                      brushSize: provider.brushSize,
                      isEraseMode: provider.isEraseMode,
                      colorblindMode: settings.colorblindMode,
                      gridFade: _gridFadeController,
                      transform: _transformController,
                      fillGrow: _growController,
                      sectionShimmer: _shimmerController,
                      tiltNotifier: _tiltNotifier,
                      onCellTap: (row, col) => provider.tryFillCell(row, col),
                      onCellLongPress: (row, col) {
                        provider.eyedropperHaptic();
                        _showColorPreview(context, provider, row, col);
                      },
                      onCellDragStart: () {
                        if (!provider.isMagicWandMode) provider.beginStroke();
                      },
                      onCellDrag: provider.strokeFill,
                      onCellDragEnd: provider.endStroke,
                      onCellDragCancel: provider.cancelStroke,
                      onRequestCanvasPan: (enabled) {
                        _canvasPanNotifier.value = enabled;
                      },
                    ),
                  );
                },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      // BackdropFilter removed: the persistent real-time backdrop blur was a
      // major raster-thread cost. Near-opaque solid panel instead.
      child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withAlpha(222) : Colors.white.withAlpha(240),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(15),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NumberToolbar(
                provider: provider,
                settings: settings,
                onHint: () => _useHint(provider, settings),
              ),
              const SizedBox(height: 12),
              NumberPalette(provider: provider),
              // The coloring screen is where users spend their time — the banner
              // lives here for free users.
              if (!settings.isProUser)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: AdBanner(),
                ),
            ],
          ),
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
    AnalyticsService()
        .logBoosterUsed(type: 'hint', remaining: settings.hintsAvailable);
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
              if (AppConfig.disableAds || !AppConfig.showAds) {
                if (forHints) {
                  settings.addHints(adAmount);
                } else {
                  provider.addMagicWands(adAmount);
                }
                _showInfoSnack('[Simulated Ad] +$adAmount $label earned!');
                return;
              }
              adService.showRewardedAd(
                placement: forHints ? 'refill_hints' : 'refill_wands',
                onRewarded: () {
                  if (forHints) {
                    settings.addHints(adAmount);
                  } else {
                    provider.addMagicWands(adAmount);
                  }
                  _showInfoSnack('+$adAmount $label earned!');
                },
                onUnavailable: () => _showInfoSnack(
                    'No ad available right now — try again later.'),
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
    if (_isPart) {
      // Parts never export their own PNG — the merged parent is saved by
      // PartSelectionScreen once every tile is done. Flush the save first:
      // markCompleted's all-parts check reads the _pct pref written there.
      await provider.saveProgress();
      if (context.mounted && provider.isComplete) {
        context.read<GalleryProvider>().markCompleted(widget.art.id);
      }
      return;
    }
    final storageService = context.read<LocalStorageService>();
    final databaseService = context.read<DatabaseService>();
    final screenshotService = ScreenshotService(storageService);
    // This runs unawaited on every artwork completion; a full disk or a
    // capture failure must degrade like the null early-returns, not become an
    // uncaught async error.
    try {
      final pngBytes = await screenshotService.captureAsPng(_repaintKey);
      if (pngBytes == null) return;
      final path =
          await screenshotService.saveArtwork(pngBytes, widget.art.name);
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
    } catch (_) {
      return;
    }
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
}


/// A square icon+label action tile used inside the completion HUD. Renders
/// dimmed and non-interactive when [onTap] is null (e.g. GIF still rendering).
class _HudAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _HudAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    final activeColor = color ?? AppStyle.primary;
    final fg = enabled
        ? activeColor
        : (isDark ? Colors.white30 : Colors.black26);
    final bg = enabled
        ? activeColor.withAlpha(isDark ? 45 : 22)
        : (isDark ? Colors.white10 : Colors.black12);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A shop row that plays a satisfying buy animation — the icon pops and a
/// green check sweeps in — when [onPurchase] reports a successful purchase.
/// "Watch an ad, earn diamonds" tile at the top of the shop — the earn path
/// for players who open the sheet with an empty balance. Shares its daily
/// claim pool with the home screen's diamond pill.
class _FreeDiamondsTile extends StatelessWidget {
  final int amount;
  final int remaining;
  final VoidCallback onWatch;

  const _FreeDiamondsTile({
    required this.amount,
    required this.remaining,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    final capped = remaining <= 0;
    const green = Color(0xFF00B894);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: green.withAlpha(40),
        child: const Icon(Icons.play_circle_fill_rounded, color: green),
      ),
      title: const Text('Free Diamonds'),
      subtitle: Text(
        capped
            ? 'Come back tomorrow!'
            : 'Watch a short ad · $remaining left today',
      ),
      trailing: ElevatedButton(
        onPressed: capped ? null : onWatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+$amount'),
            const SizedBox(width: 4),
            const Icon(Icons.diamond_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String desc;
  final int cost;
  final bool canAfford;

  /// Performs the purchase; returns true if it succeeded (diamonds spent).
  final bool Function() onPurchase;

  const _ShopTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.desc,
    required this.cost,
    required this.canAfford,
    required this.onPurchase,
  });

  @override
  State<_ShopTile> createState() => _ShopTileState();
}

class _ShopTileState extends State<_ShopTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  bool _justBought = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // Bounce out and settle back: 1 → 1.35 → 1.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_pop);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.onPurchase()) return;
    _pop.forward(from: 0);
    setState(() => _justBought = true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _justBought = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ScaleTransition(
        scale: _scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              backgroundColor: widget.color.withAlpha(40),
              child: Icon(widget.icon, color: widget.color),
            ),
            // Green check sweeps over the icon right after a successful buy.
            AnimatedOpacity(
              opacity: _justBought ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF00B894),
                child: Icon(Icons.check_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      title: Text(widget.name),
      subtitle: Text(widget.desc),
      trailing: ElevatedButton(
        onPressed: widget.canAfford ? _handleTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppStyle.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.cost}'),
            const SizedBox(width: 4),
            const Icon(Icons.diamond_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

Rect _calculateViewportRect(Matrix4 transform, Size viewerSize, double cellSize, PixelArt art) {
  if (viewerSize == Size.zero || art.gridWidth <= 0 || art.gridHeight <= 0) {
    return const Rect.fromLTRB(0, 0, 1, 1);
  }
  final scale = transform.getMaxScaleOnAxis();
  final tx = transform.entry(0, 3);
  final ty = transform.entry(1, 3);

  final canvasWidth = art.gridWidth * cellSize;
  final canvasHeight = art.gridHeight * cellSize;

  // The grid sits Center-ed inside the viewer, so its origin in child
  // coordinates is offset by the letterbox margins — subtract them or the
  // minimap viewport drifts (obvious on portrait art, where height is the
  // binding fit axis and the horizontal margin is large).
  final gridLeft = max(0.0, (viewerSize.width - canvasWidth) / 2);
  final gridTop = max(0.0, (viewerSize.height - canvasHeight) / 2);

  final left = (-tx / scale - gridLeft).clamp(0.0, canvasWidth);
  final top = (-ty / scale - gridTop).clamp(0.0, canvasHeight);
  final right =
      ((viewerSize.width - tx) / scale - gridLeft).clamp(0.0, canvasWidth);
  final bottom =
      ((viewerSize.height - ty) / scale - gridTop).clamp(0.0, canvasHeight);

  return Rect.fromLTRB(
    left / canvasWidth,
    top / canvasHeight,
    right / canvasWidth,
    bottom / canvasHeight,
  );
}

class _MiniMapPainter extends CustomPainter {
  final PixelArt art;
  final List<List<int>> filledGrid;
  final Map<int, Color> filledColors;

  /// Monotonic fill-state counter from the provider. The grid list is mutated
  /// in place, so comparing it by reference never detects changes — the
  /// version both fixes that staleness and lets zoom/pan frames skip this
  /// (whole-grid) repaint entirely.
  final int fillVersion;

  /// The provider's dirty-cell journal query; lets the baked map patch only
  /// the changed texels instead of re-rasterizing the whole grid per fill.
  final List<(int, int)>? Function(int sinceVersion)? changesSince;

  _MiniMapPainter({
    required this.art,
    required this.filledGrid,
    required this.filledColors,
    required this.fillVersion,
    this.changesSince,
  });

  // One texel per cell, baked once and patched incrementally — repainting all
  // W×H rects on every fill made stroke frames O(grid). Static so the cache
  // outlives painter instances (recreated per provider notify); keyed on art
  // id + fillVersion.
  static ui.Image? _cachedImage;
  static String _cachedArtId = '';
  static int _cachedFillVersion = -1;

  /// Frees the baked map; called from the coloring screen's dispose.
  static void releaseCache() {
    _cachedImage?.dispose();
    _cachedImage = null;
    _cachedArtId = '';
    _cachedFillVersion = -1;
  }

  Color _texelColor(int r, int c) {
    final val = art.grid[r][c];
    if (val <= 0) return const Color(0x00000000);
    final isFilled =
        r < filledGrid.length && c < filledGrid[r].length && filledGrid[r][c] > 0;
    if (isFilled) return filledColors[val] ?? const Color(0x00000000);
    return const Color(0xFFD6D6D6);
  }

  void _updateImageIfNeeded(int width, int height) {
    if (_cachedImage != null &&
        _cachedArtId == art.id &&
        _cachedFillVersion == fillVersion) {
      return;
    }
    // Texels must stay exact — BlendMode.src replaces (an erase clears back
    // to the unfilled gray), and cell state is read fresh from the grid so
    // journal duplicates/ordering don't matter.
    final paint = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.src;

    final prior = _cachedImage;
    if (prior != null &&
        _cachedArtId == art.id &&
        prior.width == width &&
        prior.height == height) {
      final dirty = changesSince?.call(_cachedFillVersion);
      if (dirty != null) {
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder);
        c.drawImage(prior, Offset.zero, Paint()..isAntiAlias = false);
        for (final (r, col) in dirty) {
          if (r < 0 || r >= height || col < 0 || col >= width) continue;
          paint.color = _texelColor(r, col);
          c.drawRect(
            Rect.fromLTWH(col.toDouble(), r.toDouble(), 1.0, 1.0),
            paint,
          );
        }
        final picture = recorder.endRecording();
        _cachedImage = picture.toImageSync(width, height);
        picture.dispose();
        prior.dispose();
        _cachedFillVersion = fillVersion;
        return;
      }
    }

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    for (var r = 0; r < height; r++) {
      for (var col = 0; col < width; col++) {
        final color = _texelColor(r, col);
        if (color.a == 0.0) continue;
        paint.color = color;
        c.drawRect(
          Rect.fromLTWH(col.toDouble(), r.toDouble(), 1.0, 1.0),
          paint,
        );
      }
    }
    final picture = recorder.endRecording();
    prior?.dispose();
    _cachedImage = picture.toImageSync(width, height);
    picture.dispose();
    _cachedArtId = art.id;
    _cachedFillVersion = fillVersion;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (art.gridWidth <= 0 || art.gridHeight <= 0) return;
    _updateImageIfNeeded(art.gridWidth, art.gridHeight);
    final image = _cachedImage;
    if (image == null) return;
    // Bilinear scaling approximates the soft cell edges the anti-aliased
    // per-rect drawing produced at minimap scale.
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        0,
        art.gridWidth.toDouble(),
        art.gridHeight.toDouble(),
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.art != art || oldDelegate.fillVersion != fillVersion;
  }
}

class _MiniMapViewportPainter extends CustomPainter {
  final Rect viewportRect;

  _MiniMapViewportPainter({required this.viewportRect});

  @override
  void paint(Canvas canvas, Size size) {
    final vpPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final vpRect = Rect.fromLTRB(
      viewportRect.left * size.width,
      viewportRect.top * size.height,
      viewportRect.right * size.width,
      viewportRect.bottom * size.height,
    );
    canvas.drawRect(vpRect, vpPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapViewportPainter oldDelegate) =>
      oldDelegate.viewportRect != viewportRect;
}

class _ProgressGiftsBar extends StatelessWidget {
  final double progress;

  const _ProgressGiftsBar({required this.progress});

  Widget _buildGiftIcon(BuildContext context, int giftIndex, bool isUnlocked) {
    final Color color;
    if (giftIndex == 1) {
      color = const Color(0xFF00BCD4);
    } else if (giftIndex == 2) {
      color = const Color(0xFFFFB300);
    } else {
      color = const Color(0xFFE53935);
    }

    // Pop when a gift unlocks: quick scale bounce alongside the color change.
    return AnimatedScale(
      scale: isUnlocked ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      child: Icon(
        Icons.redeem_rounded,
        size: 18,
        color: isUnlocked ? color : color.withAlpha(100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The tween re-targets whenever progress changes, so every fill eases the
    // bar (and counts the % up) instead of snapping.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth - 52;
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: animated,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF81C784), Color(0xFF4CAF50)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (trackWidth * 0.30) - 9,
                          child: _buildGiftIcon(context, 1, animated >= 0.30),
                        ),
                        Positioned(
                          left: (trackWidth * 0.65) - 9,
                          child: _buildGiftIcon(context, 2, animated >= 0.65),
                        ),
                        Positioned(
                          left: trackWidth - 9,
                          child: _buildGiftIcon(context, 3, animated >= 1.0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(animated * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
