import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/flavor.dart';
import '../../data/services/local_storage_service.dart';
import '../motion.dart';
import '../theme/app_style.dart';
import '../widgets/number_toolbar.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'home_screen.dart';

/// Interactive onboarding flow shown after the splash screen on first launch
/// (or re-opened anytime from Settings / Profile as a game guide).
class OnboardingScreen extends StatefulWidget {
  /// When true, navigating away pops the screen instead of pushing [HomeScreen].
  final bool isReplay;

  /// Optional callback invoked when the user finishes or skips onboarding.
  final VoidCallback? onFinished;

  const OnboardingScreen({
    super.key,
    this.isReplay = false,
    this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  // Background floating ambient particles
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    final storage = context.read<LocalStorageService>();
    storage.setBool('has_seen_onboarding', true);

    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        fadeThroughRoute(const HomeScreen(), name: 'home'),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Motion.standard,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Motion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = flavor.primary;
    final secondaryColor = flavor.secondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF7F8FD),
      body: Stack(
        children: [
          // Background ambient gradient aura
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.4, -0.6),
                  radius: 1.3,
                  colors: [
                    primaryColor.withAlpha(isDark ? 55 : 30),
                    secondaryColor.withAlpha(isDark ? 30 : 15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Floating pixel dust animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _OnboardingParticlesPainter(
                    progress: _ambientController.value,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // Content area
          SafeArea(
            child: Column(
              children: [
                // Top header bar: Brand tag and Skip button
                _buildTopBar(context, isDark, primaryColor),

                // Main PageView for onboarding slides
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    children: [
                      _HowToPlaySlide(
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                      ),
                      _ZoomPanSlide(
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                      ),
                      _BoostersSlide(
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                      ),
                      _ReplayAndFeaturesSlide(
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // Bottom control dock: indicator dots and action buttons
                _buildBottomControls(context, isDark, primaryColor, secondaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App/Guide Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(25) : primaryColor.withAlpha(40),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: isDark ? const Color(0xFFFFD700) : primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isReplay ? 'Game Guide' : FlavorConfig.current.appName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white.withAlpha(230) : primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Skip / Close Button
          PressableScale(
            onTap: _finishOnboarding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.isReplay
                    ? 'Close'
                    : (_currentPage == _totalPages - 1 ? '' : 'Skip'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withAlpha(180) : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Motion.standard,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 7,
                width: isSelected ? 26 : 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: isSelected
                      ? LinearGradient(colors: [primaryColor, secondaryColor])
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? Colors.white24 : Colors.black12),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Action Buttons: Back & Next / Start
          Row(
            children: [
              // Back Button
              AnimatedOpacity(
                opacity: _currentPage > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: PressableScale(
                  onTap: _currentPage > 0 ? _prevPage : null,
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withAlpha(16)
                          : Colors.black.withAlpha(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(15),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Main Forward Button (Morphs to "Start Coloring" on last page)
              Expanded(
                child: PressableScale(
                  key: const ValueKey('main_action_btn'),
                  onTap: _nextPage,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(isDark ? 90 : 70),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: isLastPage
                            ? const Row(
                                key: ValueKey('start_btn'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.palette_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Coloring!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                key: ValueKey('next_btn'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Next',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SLIDE 1: How to Play (Tap & Drag to Color by Number)
// ---------------------------------------------------------------------------
class _HowToPlaySlide extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  const _HowToPlaySlide({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  State<_HowToPlaySlide> createState() => _HowToPlaySlideState();
}

class _HowToPlaySlideState extends State<_HowToPlaySlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _stepAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _stepAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingSlideLayout(
      badge: 'STEP 1 · THE BASICS',
      badgeColor: const Color(0xFFFF4757),
      title: 'Tap & Drag to Color',
      subtitle:
          'Select a numbered color from the palette, find matching cells on the canvas, and tap or glide your finger to paint them instantly.',
      isDark: widget.isDark,
      child: _buildInteractiveGridDemo(),
    );
  }

  Widget _buildInteractiveGridDemo() {
    return AnimatedBuilder(
      animation: _stepAnim,
      builder: (context, _) {
        final t = _animController.value;

        // Stage 0.0 - 0.25: Select Color #1 in palette
        // Stage 0.25 - 0.70: Finger moves across cells and colors matching '1's
        // Stage 0.70 - 0.90: Pop sparkles & completion check
        // Stage 0.90 - 1.00: Pause and loop

        final paletteSelected = t > 0.15;
        final cell1Filled = t > 0.35;
        final cell2Filled = t > 0.50;
        final cell3Filled = t > 0.65;
        final isComplete = t > 0.72;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini Canvas Frame
            Container(
              width: 240,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF19182C)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withAlpha(widget.isDark ? 50 : 30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(12),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 5x5 Cute Pixel Heart Layout
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row 0
                      _buildRow([
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 1, filled: cell1Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 1, filled: cell2Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                      ]),
                      const SizedBox(height: 4),
                      // Row 1
                      _buildRow([
                        _Pixel(num: 1, filled: cell1Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 1, filled: cell2Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                      ]),
                      const SizedBox(height: 4),
                      // Row 2
                      _buildRow([
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                      ]),
                      const SizedBox(height: 4),
                      // Row 3
                      _buildRow([
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 2, filled: true, color: const Color(0xFFBD93F9), active: false),
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                      ]),
                      const SizedBox(height: 4),
                      // Row 4
                      _buildRow([
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 1, filled: cell3Filled, color: const Color(0xFFFF3366), active: paletteSelected),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                        _Pixel(num: 0, filled: false, color: Colors.transparent),
                      ]),
                    ],
                  ),

                  // Success celebration banner
                  if (isComplete)
                    Positioned(
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ED573),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ED573).withAlpha(100),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Color #1 Complete!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Animated Hand / Pointer Cursor
                  _buildAnimatedCursor(t),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Simulated Palette Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1B1A30) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withAlpha(18)
                      : Colors.black.withAlpha(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PaletteItem(
                    number: 1,
                    color: const Color(0xFFFF3366),
                    isSelected: paletteSelected,
                  ),
                  const SizedBox(width: 8),
                  _PaletteItem(
                    number: 2,
                    color: const Color(0xFFBD93F9),
                    isSelected: false,
                    isDone: true,
                  ),
                  const SizedBox(width: 8),
                  _PaletteItem(
                    number: 3,
                    color: const Color(0xFFFFBE2E),
                    isSelected: false,
                  ),
                  const SizedBox(width: 8),
                  _PaletteItem(
                    number: 4,
                    color: const Color(0xFF2ED573),
                    isSelected: false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: child,
              ))
          .toList(),
    );
  }

  Widget _buildAnimatedCursor(double t) {
    // Calculates finger path: palette -> cell 1 -> cell 2 -> cell 3
    double dx = 0;
    double dy = 0;
    double scale = 1.0;

    if (t < 0.20) {
      // Resting on palette
      dx = -45;
      dy = 75;
      scale = 0.9;
    } else if (t < 0.40) {
      // Moving to top-left cell 1
      final p = (t - 0.20) / 0.20;
      dx = -45 + (-30 - -45) * p;
      dy = 75 + (-50 - 75) * p;
      scale = 0.9 + 0.1 * math.sin(p * math.pi);
    } else if (t < 0.60) {
      // Gliding to top-right cell 1
      final p = (t - 0.40) / 0.20;
      dx = -30 + (30 - -30) * p;
      dy = -50 + (-50 - -50) * p;
    } else if (t < 0.75) {
      // Gliding down to center cells
      final p = (t - 0.60) / 0.15;
      dx = 30 + (0 - 30) * p;
      dy = -50 + (10 - -50) * p;
    } else {
      // Completed, pulling back
      dx = 60;
      dy = 60;
      scale = 0.8;
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(220),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withAlpha(120),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF2A2B4A),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pixel extends StatelessWidget {
  final int num;
  final bool filled;
  final Color color;
  final bool active;

  const _Pixel({
    required this.num,
    required this.filled,
    required this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    if (num == 0) {
      return const SizedBox(width: 26, height: 26);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Motion.standard,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: filled ? color : (active ? Colors.white.withAlpha(40) : Colors.black12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active && !filled
              ? color
              : (filled ? color : Colors.white24),
          width: active && !filled ? 2 : 1,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withAlpha(100),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: filled
            ? const SizedBox.shrink()
            : Text(
                '$num',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? color : Colors.white60,
                ),
              ),
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  final int number;
  final Color color;
  final bool isSelected;
  final bool isDone;

  const _PaletteItem({
    required this.number,
    required this.color,
    required this.isSelected,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withAlpha(180),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SLIDE 2: Zoom in/out and Pan (Effortless Navigation)
// ---------------------------------------------------------------------------
class _ZoomPanSlide extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  const _ZoomPanSlide({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  State<_ZoomPanSlide> createState() => _ZoomPanSlideState();
}

class _ZoomPanSlideState extends State<_ZoomPanSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoomAnimController;

  @override
  void initState() {
    super.initState();
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingSlideLayout(
      badge: 'STEP 2 · PRECISION',
      badgeColor: const Color(0xFF00F0FF),
      title: 'Pinch to Zoom & Pan',
      subtitle:
          'Pinch with two fingers to zoom in on intricate pixel numbers, or zoom out to admire the big picture. Drag smoothly to navigate anywhere on large canvases.',
      isDark: widget.isDark,
      child: _buildZoomDemo(),
    );
  }

  Widget _buildZoomDemo() {
    return AnimatedBuilder(
      animation: _zoomAnimController,
      builder: (context, _) {
        final t = _zoomAnimController.value;

        // Stage 0.0 - 0.40: Zoom in from 1.0x to 2.2x
        // Stage 0.40 - 0.70: Pan across
        // Stage 0.70 - 0.90: Zoom out smoothly
        // Stage 0.90 - 1.00: Reset pause

        double scale = 1.0;
        double panX = 0;
        double panY = 0;
        double pinchSpread = 20;

        if (t < 0.40) {
          final p = Curves.easeInOutCubic.transform(t / 0.40);
          scale = 1.0 + 1.2 * p;
          pinchSpread = 20 + 35 * p;
        } else if (t < 0.70) {
          final p = Curves.easeInOut.transform((t - 0.40) / 0.30);
          scale = 2.2;
          panX = -25 * math.sin(p * math.pi);
          panY = -15 * math.sin(p * math.pi);
          pinchSpread = 55;
        } else if (t < 0.92) {
          final p = Curves.easeInOutCubic.transform((t - 0.70) / 0.22);
          scale = 2.2 - 1.2 * p;
          pinchSpread = 55 - 35 * p;
        }

        final showNumbers = scale > 1.4;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 250,
              height: 200,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.secondaryColor.withAlpha(widget.isDark ? 40 : 25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated Zoom Canvas
                  Transform.translate(
                    offset: Offset(panX, panY),
                    child: Transform.scale(
                      scale: scale,
                      child: _buildPixelArtMesh(showNumbers),
                    ),
                  ),

                  // Floating Magnifier Indicator Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.black54 : Colors.white70,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.primaryColor.withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scale > 1.2 ? Icons.zoom_in_rounded : Icons.zoom_out_rounded,
                            size: 14,
                            color: widget.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(scale * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Gesture Finger Rings (Pinch Visualization)
                  if (t < 0.40 || (t >= 0.70 && t < 0.92))
                    _buildPinchGestureRings(pinchSpread),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tip Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: widget.primaryColor.withAlpha(widget.isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_rounded, size: 16, color: widget.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Pinch outward to zoom in · Inward to zoom out',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPixelArtMesh(bool showNumbers) {
    // 6x6 colorful pixel icon
    final palette = [
      const Color(0xFFFF5252),
      const Color(0xFFFF793F),
      const Color(0xFFFFDA79),
      const Color(0xFF33D9B2),
      const Color(0xFF34ACE0),
      const Color(0xFF706FD3),
    ];

    return SizedBox(
      width: 130,
      height: 130,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 36,
        itemBuilder: (context, i) {
          final color = palette[i % palette.length];
          final isRevealed = (i % 2 == 0);
          final number = (i % 6) + 1;

          return Container(
            decoration: BoxDecoration(
              color: isRevealed
                  ? color
                  : (widget.isDark ? const Color(0xFF26253E) : const Color(0xFFEEEEEE)),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: widget.isDark ? Colors.white12 : Colors.black12,
                width: 0.5,
              ),
            ),
            child: Center(
              child: (!isRevealed && showNumbers)
                  ? Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinchGestureRings(double spread) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(-spread, -spread * 0.7),
          child: _FingerRing(color: widget.primaryColor),
        ),
        Transform.translate(
          offset: Offset(spread, spread * 0.7),
          child: _FingerRing(color: widget.secondaryColor),
        ),
      ],
    );
  }
}

class _FingerRing extends StatelessWidget {
  final Color color;
  const _FingerRing({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(70),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(120),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SLIDE 3: Power-ups & Boosters (Bomb, Magic Wand, Smart Hints)
// ---------------------------------------------------------------------------
class _BoostersSlide extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  const _BoostersSlide({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  State<_BoostersSlide> createState() => _BoostersSlideState();
}

class _BoostersSlideState extends State<_BoostersSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bombController;

  @override
  void initState() {
    super.initState();
    _bombController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _bombController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingSlideLayout(
      badge: 'STEP 3 · POWER-UPS',
      badgeColor: const Color(0xFFFF9F1A),
      title: 'Color Bomb & Boosters',
      subtitle:
          'Supercharge your flow with game-changing boosters! Unleash the Color Bomb for an explosive area blast, tap the Paint Bucket to color all cells of a number, or use the 3x3 Brush for multi-cell speed.',
      isDark: widget.isDark,
      child: _buildBoosterVisuals(),
    );
  }

  Widget _buildBoosterVisuals() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bomb Blast Wave Interactive Stage
        AnimatedBuilder(
          animation: _bombController,
          builder: (context, _) {
            final t = _bombController.value;

            // 0.0 - 0.40: Bomb ticks and pulses with fuse spark
            // 0.40 - 0.75: Bomb explodes with expanding shockwave rings and colorful cells popping!
            // 0.75 - 1.00: Fade out / reset
            final isExploding = t > 0.40 && t < 0.85;
            final blastProgress = isExploding ? ((t - 0.40) / 0.45) : 0.0;

            return Container(
              width: 250,
              height: 140,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4757).withAlpha(widget.isDark ? 50 : 30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Surrounding Pixel Grid
                  _buildSurroundingGrid(blastProgress),

                  // Shockwave ring
                  if (isExploding)
                    Transform.scale(
                      scale: 0.5 + blastProgress * 2.2,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4757).withAlpha(
                              ((1.0 - blastProgress).clamp(0.0, 1.0) * 255).round(),
                            ),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD32A).withAlpha(
                                ((0.8 * (1.0 - blastProgress)).clamp(0.0, 1.0) * 255).round(),
                              ),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Center Bomb or Explosion Flash
                  if (!isExploding)
                    _buildPulsingBomb(t)
                  else
                    _buildExplosionFlash(blastProgress),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3 Booster Cards Row using exact coloring screen toolbar icons and badge styles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BoosterFeatureChip(
              icon: const SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: BombIconPainter()),
              ),
              badgeValue: '3',
              badgeColor: Colors.orange,
              accentColor: const Color(0xFFFF4757),
              label: 'Color Bomb',
              description: 'Area blast',
              isDark: widget.isDark,
            ),
            const SizedBox(width: 8),
            _BoosterFeatureChip(
              icon: const Icon(
                Icons.format_color_fill_rounded,
                color: Colors.blueAccent,
                size: 24,
              ),
              badgeValue: '5',
              badgeColor: Colors.orange,
              accentColor: Colors.blueAccent,
              label: 'Paint Bucket',
              description: 'Fill all cells',
              isDark: widget.isDark,
            ),
            const SizedBox(width: 8),
            _BoosterFeatureChip(
              icon: SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(
                  painter: MultiCellIconPainter(
                    isMulti: true,
                    isDark: widget.isDark,
                    activeColor: const Color(0xFFE91E63),
                  ),
                ),
              ),
              badgeValue: '3x3',
              badgeColor: const Color(0xFFE91E63),
              accentColor: const Color(0xFFE91E63),
              label: '3x3 Brush',
              description: 'Multi-cell fill',
              isDark: widget.isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSurroundingGrid(double blastProgress) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: 45,
      itemBuilder: (context, i) {
        final row = i ~/ 9;
        final col = i % 9;
        final dist = math.sqrt(math.pow(row - 2.5, 2) + math.pow(col - 4, 2));
        final isColoredByBlast = blastProgress > (dist / 6.0);

        final cellColor = isColoredByBlast
            ? AppStyle.paletteColors[i % AppStyle.paletteColors.length]
            : (widget.isDark ? const Color(0xFF26253E) : const Color(0xFFEEEEEE));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }

  Widget _buildPulsingBomb(double t) {
    final pulse = 1.0 + 0.12 * math.sin(t * math.pi * 8);

    return Transform.scale(
      scale: pulse,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark ? const Color(0xFF1E1D32) : Colors.white,
          border: Border.all(
            color: widget.isDark ? Colors.white.withAlpha(40) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4757).withAlpha(widget.isDark ? 100 : 70),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CustomPaint(
              painter: BombIconPainter(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplosionFlash(double blastProgress) {
    return Opacity(
      opacity: (1.0 - blastProgress).clamp(0.0, 1.0),
      child: const Icon(
        Icons.auto_awesome,
        color: Color(0xFFFFD32A),
        size: 54,
      ),
    );
  }
}

class _BoosterFeatureChip extends StatelessWidget {
  final Widget icon;
  final String badgeValue;
  final Color? badgeColor;
  final Color accentColor;
  final String label;
  final String description;
  final bool isDark;

  const _BoosterFeatureChip({
    required this.icon,
    required this.badgeValue,
    this.badgeColor,
    required this.accentColor,
    required this.label,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1A30) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 35 : 18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Tool Button identical to coloring screen NumberToolbar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withAlpha(16) : Colors.white,
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(child: icon),
              ),
              // Floating Badge in Top Right
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 14,
                  ),
                  child: Center(
                    child: Text(
                      badgeValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SLIDE 4: Create, Replay & Daily Puzzles
// ---------------------------------------------------------------------------
class _ReplayAndFeaturesSlide extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  const _ReplayAndFeaturesSlide({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  State<_ReplayAndFeaturesSlide> createState() => _ReplayAndFeaturesSlideState();
}

class _ReplayAndFeaturesSlideState extends State<_ReplayAndFeaturesSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _replayController;

  @override
  void initState() {
    super.initState();
    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _replayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingSlideLayout(
      badge: 'STEP 4 · MASTERPIECES',
      badgeColor: const Color(0xFF2ED573),
      title: 'Time-Lapse & Daily Art',
      subtitle:
          'Relive your coloring journey with animated time-lapse video replays, unlock exclusive daily puzzle drops, and turn your own photos into pixel art!',
      isDark: widget.isDark,
      child: _buildReplayCard(),
    );
  }

  Widget _buildReplayCard() {
    return AnimatedBuilder(
      animation: _replayController,
      builder: (context, _) {
        final progress = _replayController.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Replay Showcase Mockup
            Container(
              width: 250,
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.primaryColor.withAlpha(widget.isDark ? 80 : 40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withAlpha(widget.isDark ? 50 : 25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header inside card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, size: 16, color: Color(0xFF2ED573)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Time-Lapse Replay',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ED573).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HD 60FPS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2ED573),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Animated Replay Artwork Visual
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (col) {
                      final isRevealed = progress > (col / 6.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: isRevealed
                                ? LinearGradient(
                                    colors: [
                                      AppStyle.paletteColors[col % AppStyle.paletteColors.length],
                                      AppStyle.paletteColors[(col + 2) % AppStyle.paletteColors.length],
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : null,
                            color: isRevealed
                                ? null
                                : (widget.isDark ? const Color(0xFF27263E) : Colors.black12),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Progress Scrubber Bar
                  Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: widget.isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation(widget.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Feature Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _FeaturePill(
                  icon: Icons.calendar_today_rounded,
                  label: 'Daily Pixels',
                  color: const Color(0xFFFF9F1A),
                  isDark: widget.isDark,
                ),
                _FeaturePill(
                  icon: Icons.camera_alt_rounded,
                  label: 'Photo Converter',
                  color: const Color(0xFF00F0FF),
                  isDark: widget.isDark,
                ),
                _FeaturePill(
                  icon: Icons.share_rounded,
                  label: 'Easy Sharing',
                  color: const Color(0xFFBD93F9),
                  isDark: widget.isDark,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1A30) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(isDark ? 80 : 50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withAlpha(220) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Standard Layout for each Onboarding Slide
// ---------------------------------------------------------------------------
class _OnboardingSlideLayout extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isDark;

  const _OnboardingSlideLayout({
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // Interactive Visual Card
                  child,
                  const SizedBox(height: 16),

                  // Slide Badge Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withAlpha(60)),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF14142B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white70 : Colors.black87.withAlpha(180),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Ambient Floating Pixel Particles
// ---------------------------------------------------------------------------
class _OnboardingParticlesPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  static final List<_ParticleData> _particles = () {
    final rng = math.Random(1337);
    return List.generate(20, (i) {
      return _ParticleData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 3.5 + rng.nextDouble() * 5.0,
        speed: 0.3 + rng.nextDouble() * 0.7,
        alpha: 0.08 + rng.nextDouble() * 0.18,
        useSecondary: rng.nextBool(),
      );
    });
  }();

  _OnboardingParticlesPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final curY = ((p.y - progress * p.speed) % 1.0) * size.height;
      final curX = (p.x * size.width) + math.sin(progress * 2 * math.pi + p.y * 10) * 8;

      final color = p.useSecondary ? secondaryColor : primaryColor;
      final paint = Paint()
        ..color = color.withAlpha(((p.alpha * (isDark ? 1.0 : 0.6)).clamp(0.0, 1.0) * 255).round())
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(curX, curY),
            width: p.size,
            height: p.size,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingParticlesPainter oldDelegate) => true;
}

class _ParticleData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double alpha;
  final bool useSecondary;

  const _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.alpha,
    required this.useSecondary,
  });
}
