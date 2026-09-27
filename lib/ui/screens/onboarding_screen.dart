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

  static const List<({String title, IconData icon})> _topics = [
    (title: 'Basics', icon: Icons.palette_rounded),
    (title: 'Zoom', icon: Icons.zoom_in_rounded),
    (title: 'Boosters', icon: Icons.bolt_rounded),
    (title: 'Features', icon: Icons.auto_awesome_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    try {
      final storage = context.read<LocalStorageService>();
      storage.setBool('has_seen_onboarding', true);
    } catch (_) {}

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

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Motion.standard,
    );
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
      backgroundColor: isDark ? const Color(0xFF0D0D18) : const Color(0xFFF7F8FD),
      body: Stack(
        children: [
          // Background ambient gradient aura
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.3, -0.5),
                  radius: 1.4,
                  colors: [
                    primaryColor.withAlpha(isDark ? 50 : 25),
                    secondaryColor.withAlpha(isDark ? 28 : 12),
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
                // Top header bar: Brand tag, Guide Pill and Skip/Close button
                _buildTopBar(context, isDark, primaryColor, secondaryColor),

                // Interactive Quick Topic Tabs Selector
                _buildTopicTabs(isDark, primaryColor, secondaryColor),

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
                        isReplay: widget.isReplay,
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

  Widget _buildTopBar(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App / Guide Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(16)
                  : primaryColor.withAlpha(16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(22) : primaryColor.withAlpha(35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isReplay ? Icons.menu_book_rounded : Icons.auto_awesome_rounded,
                  size: 14,
                  color: isDark ? const Color(0xFFFFD700) : primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isReplay ? 'How to Play Guide' : FlavorConfig.current.appName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.white.withAlpha(230) : primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(isDark ? 50 : 30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : primaryColor,
                    ),
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
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(18) : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isReplay) ...[
                    Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white.withAlpha(200) : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    widget.isReplay
                        ? 'Close'
                        : (_currentPage == _totalPages - 1 ? '' : 'Skip'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withAlpha(190) : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTabs(bool isDark, Color primaryColor, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161528) : Colors.black.withAlpha(8),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(12),
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: List.generate(_topics.length, (index) {
            final isSelected = index == _currentPage;
            final topic = _topics[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => _goToPage(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Motion.standard,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withAlpha(isDark ? 90 : 60),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          topic.icon,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            topic.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isSelected = index == _currentPage;
              return GestureDetector(
                onTap: () => _goToPage(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Motion.standard,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: isSelected ? 24 : 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: isSelected
                        ? LinearGradient(colors: [primaryColor, secondaryColor])
                        : null,
                    color: isSelected
                        ? null
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

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
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withAlpha(16)
                          : Colors.black.withAlpha(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(22)
                            : Colors.black.withAlpha(14),
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

              // Main Forward Button (Morphs to "Start Coloring!" on last page)
              Expanded(
                child: PressableScale(
                  key: const ValueKey('main_action_btn'),
                  onTap: _nextPage,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(isDark ? 90 : 70),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
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
// SLIDE 1: How to Play (Tap & Drag to Color by Number) - Truly Hands-On Interactive!
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

  // Real user interaction state
  int _selectedColorIndex = 1;
  final Set<int> _userFilledCells = <int>{};
  bool _userInteracted = false;
  DateTime _lastUserTouch = DateTime.now();

  static const List<int> _heartGrid = [
    0, 1, 0, 1, 0,
    1, 2, 1, 2, 1,
    1, 2, 2, 2, 1,
    0, 1, 2, 1, 0,
    0, 0, 1, 0, 0,
  ];

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

  void _onCellTapped(int index) {
    final cellNum = _heartGrid[index];
    if (cellNum == 0) return;

    setState(() {
      _userInteracted = true;
      _lastUserTouch = DateTime.now();
      if (cellNum == _selectedColorIndex) {
        _userFilledCells.add(index);
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    });
  }

  void _onPaletteTapped(int num) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedColorIndex = num;
      _userInteracted = true;
      _lastUserTouch = DateTime.now();
    });
  }

  void _resetInteractiveDemo() {
    HapticFeedback.mediumImpact();
    setState(() {
      _userFilledCells.clear();
      _selectedColorIndex = 1;
      _userInteracted = false;
    });
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

        // If user touched within the last 5 seconds, use user interactive state.
        final now = DateTime.now();
        final isUsingAutoDemo = !_userInteracted ||
            now.difference(_lastUserTouch).inSeconds > 5;

        final autoCell1Filled = t > 0.35;
        final autoCell2Filled = t > 0.50;
        final autoCell3Filled = t > 0.65;
        final autoIsComplete = t > 0.72;

        final effectivePaletteNum = isUsingAutoDemo ? 1 : _selectedColorIndex;

        final totalNum1Cells = _heartGrid.where((v) => v == 1).length;
        final filledNum1Cells = _userFilledCells
            .where((i) => _heartGrid[i] == 1)
            .length;
        final isAllNum1Filled = filledNum1Cells == totalNum1Cells;

        final showCompleteBanner = isUsingAutoDemo ? autoIsComplete : isAllNum1Filled;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive Mini Canvas Frame
            Container(
              width: 250,
              height: 205,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withAlpha(widget.isDark ? 55 : 30),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withAlpha(22)
                      : Colors.black.withAlpha(12),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 5x5 Heart Grid (Interactive on tap & drag)
                  GestureDetector(
                    onPanUpdate: (details) {
                      // Allow drag coloring
                      final renderBox = context.findRenderObject() as RenderBox?;
                      if (renderBox == null) return;
                      // Drag detection fallback
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (r) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (c) {
                              final index = r * 5 + c;
                              final cellNum = _heartGrid[index];

                              bool filled;
                              if (cellNum == 0) {
                                filled = false;
                              } else if (cellNum == 2) {
                                filled = true; // Pre-filled purple for visual context
                              } else {
                                if (isUsingAutoDemo) {
                                  // Automated timeline demo
                                  if (index == 1 || index == 5) {
                                    filled = autoCell1Filled;
                                  } else if (index == 3 || index == 9) {
                                    filled = autoCell2Filled;
                                  } else {
                                    filled = autoCell3Filled;
                                  }
                                } else {
                                  filled = _userFilledCells.contains(index);
                                }
                              }

                              final isActive = (cellNum == effectivePaletteNum);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: GestureDetector(
                                  onTapDown: (_) => _onCellTapped(index),
                                  child: _Pixel(
                                    num: cellNum,
                                    filled: filled,
                                    color: cellNum == 1
                                        ? const Color(0xFFFF3366)
                                        : const Color(0xFFBD93F9),
                                    active: isActive,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Success celebration banner
                  if (showCompleteBanner)
                    Positioned(
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ED573).withAlpha(120),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Color #1 Complete! ✨',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Animated Hand / Pointer Cursor when in auto demo mode
                  if (isUsingAutoDemo) _buildAnimatedCursor(t),

                  // Interactive "Try tapping cells" hint
                  if (!_userInteracted && isUsingAutoDemo)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.black54 : Colors.white70,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Try tapping cells!',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Simulated Palette Bar (Interactive!)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1B1A30) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(widget.isDark ? 50 : 10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _onPaletteTapped(1),
                        child: _PaletteItem(
                          number: 1,
                          color: const Color(0xFFFF3366),
                          isSelected: effectivePaletteNum == 1,
                          isDone: isAllNum1Filled && !isUsingAutoDemo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _onPaletteTapped(2),
                        child: _PaletteItem(
                          number: 2,
                          color: const Color(0xFFBD93F9),
                          isSelected: effectivePaletteNum == 2,
                          isDone: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _onPaletteTapped(3),
                        child: _PaletteItem(
                          number: 3,
                          color: const Color(0xFFFFBE2E),
                          isSelected: effectivePaletteNum == 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _onPaletteTapped(4),
                        child: _PaletteItem(
                          number: 4,
                          color: const Color(0xFF2ED573),
                          isSelected: effectivePaletteNum == 4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_userInteracted) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _resetInteractiveDemo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: widget.primaryColor),
                          const SizedBox(width: 3),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCursor(double t) {
    double dx = 0;
    double dy = 0;
    double scale = 1.0;

    if (t < 0.20) {
      dx = -45;
      dy = 75;
      scale = 0.9;
    } else if (t < 0.40) {
      final p = (t - 0.20) / 0.20;
      dx = -45 + (-30 - -45) * p;
      dy = 75 + (-50 - 75) * p;
      scale = 0.9 + 0.1 * math.sin(p * math.pi);
    } else if (t < 0.60) {
      final p = (t - 0.40) / 0.20;
      dx = -30 + (30 - -30) * p;
      dy = -50;
    } else if (t < 0.75) {
      final p = (t - 0.60) / 0.15;
      dx = 30 + (0 - 30) * p;
      dy = -50 + (10 - -50) * p;
    } else {
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
            color: Colors.white.withAlpha(230),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withAlpha(140),
                blurRadius: 14,
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
      return const SizedBox(width: 28, height: 28);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Motion.standard,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: filled ? color : (active ? Colors.white.withAlpha(45) : Colors.black12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: active && !filled
              ? color
              : (filled ? color : Colors.white24),
          width: active && !filled ? 2 : 1,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withAlpha(120),
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
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: active ? color : Colors.white70,
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
      width: 34,
      height: 34,
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
                  color: color.withAlpha(190),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
            : Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
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

  double _userZoom = 1.0;
  bool _manualControl = false;

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

  void _adjustZoom(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _manualControl = true;
      _userZoom = (_userZoom + delta).clamp(1.0, 2.5);
    });
  }

  void _resetZoom() {
    HapticFeedback.mediumImpact();
    setState(() {
      _manualControl = false;
      _userZoom = 1.0;
    });
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

        double scale = 1.0;
        double panX = 0;
        double panY = 0;
        double pinchSpread = 20;

        if (_manualControl) {
          scale = _userZoom;
          panX = 0;
          panY = 0;
          pinchSpread = 20 + 35 * ((scale - 1.0) / 1.5);
        } else {
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
        }

        final showNumbers = scale > 1.35;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 255,
              height: 200,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.secondaryColor.withAlpha(widget.isDark ? 45 : 25),
                    blurRadius: 22,
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
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.black87.withAlpha(200) : Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.primaryColor.withAlpha(120)),
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

                  // Interactive Zoom Buttons on left
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ZoomButton(
                          icon: Icons.remove_rounded,
                          onTap: () => _adjustZoom(-0.3),
                          isDark: widget.isDark,
                        ),
                        const SizedBox(width: 6),
                        _ZoomButton(
                          icon: Icons.add_rounded,
                          onTap: () => _adjustZoom(0.3),
                          isDark: widget.isDark,
                        ),
                        if (_manualControl) ...[
                          const SizedBox(width: 6),
                          _ZoomButton(
                            icon: Icons.restart_alt_rounded,
                            onTap: _resetZoom,
                            isDark: widget.isDark,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Gesture Finger Rings (Pinch Visualization) when not in manual mode
                  if (!_manualControl && (t < 0.40 || (t >= 0.70 && t < 0.92)))
                    _buildPinchGestureRings(pinchSpread),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tip Pill Cards
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: widget.primaryColor.withAlpha(widget.isDark ? 30 : 18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.primaryColor.withAlpha(40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_rounded, size: 16, color: widget.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Pinch outward to reveal numbers · Pan with 2 fingers',
                    style: TextStyle(
                      fontSize: 11,
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

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? Colors.black54 : Colors.white70,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
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
// SLIDE 3: Power-ups & Boosters (Bomb, Bucket, 3x3 Brush) - Interactive!
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

  int _selectedBooster = 0; // 0 = Bomb, 1 = Bucket, 2 = 3x3 Brush

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

  void _selectBooster(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedBooster = index;
    });
    _bombController.forward(from: 0.0);
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
        // Bomb / Power-up Blast Stage
        AnimatedBuilder(
          animation: _bombController,
          builder: (context, _) {
            final t = _bombController.value;

            final isExploding = t > 0.35 && t < 0.85;
            final blastProgress = isExploding ? ((t - 0.35) / 0.50) : 0.0;

            return Container(
              width: 255,
              height: 145,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4757).withAlpha(widget.isDark ? 50 : 30),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Surrounding Pixel Grid
                  _buildSurroundingGrid(blastProgress),

                  // Shockwave ring for bomb or ripple for bucket
                  if (isExploding)
                    Transform.scale(
                      scale: 0.5 + blastProgress * 2.2,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (_selectedBooster == 1
                                    ? Colors.blueAccent
                                    : (_selectedBooster == 2
                                        ? const Color(0xFFE91E63)
                                        : const Color(0xFFFF4757)))
                                .withAlpha(
                              ((1.0 - blastProgress).clamp(0.0, 1.0) * 255).round(),
                            ),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD32A).withAlpha(
                                ((0.8 * (1.0 - blastProgress)).clamp(0.0, 1.0) * 255).round(),
                              ),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Center Bomb or Explosion Flash
                  if (!isExploding)
                    _buildPulsingToolCenter(t)
                  else
                    _buildExplosionFlash(blastProgress),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3 Booster Cards Row - Interactive Tabs
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _selectBooster(0),
              child: _BoosterFeatureChip(
                isSelected: _selectedBooster == 0,
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
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _selectBooster(1),
              child: _BoosterFeatureChip(
                isSelected: _selectedBooster == 1,
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
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _selectBooster(2),
              child: _BoosterFeatureChip(
                isSelected: _selectedBooster == 2,
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

        bool isColored = false;
        if (_selectedBooster == 0) {
          isColored = blastProgress > (dist / 6.0);
        } else if (_selectedBooster == 1) {
          isColored = (i % 2 == 0) && blastProgress > 0.2;
        } else {
          isColored = (col >= 3 && col <= 5 && row >= 1 && row <= 3) && blastProgress > 0.25;
        }

        final cellColor = isColored
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

  Widget _buildPulsingToolCenter(double t) {
    final pulse = 1.0 + 0.12 * math.sin(t * math.pi * 8);

    Widget toolIcon;
    Color accentColor;
    if (_selectedBooster == 0) {
      toolIcon = const SizedBox(
        width: 30,
        height: 30,
        child: CustomPaint(painter: BombIconPainter()),
      );
      accentColor = const Color(0xFFFF4757);
    } else if (_selectedBooster == 1) {
      toolIcon = const Icon(Icons.format_color_fill_rounded, color: Colors.blueAccent, size: 28);
      accentColor = Colors.blueAccent;
    } else {
      toolIcon = SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(
          painter: MultiCellIconPainter(
            isMulti: true,
            isDark: widget.isDark,
            activeColor: const Color(0xFFE91E63),
          ),
        ),
      );
      accentColor = const Color(0xFFE91E63);
    }

    return Transform.scale(
      scale: pulse,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark ? const Color(0xFF1E1D32) : Colors.white,
          border: Border.all(
            color: accentColor.withAlpha(widget.isDark ? 140 : 100),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withAlpha(widget.isDark ? 100 : 60),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: toolIcon),
      ),
    );
  }

  Widget _buildExplosionFlash(double blastProgress) {
    return Opacity(
      opacity: (1.0 - blastProgress).clamp(0.0, 1.0),
      child: const Icon(
        Icons.auto_awesome,
        color: Color(0xFFFFD32A),
        size: 56,
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
  final bool isSelected;

  const _BoosterFeatureChip({
    required this.icon,
    required this.badgeValue,
    this.badgeColor,
    required this.accentColor,
    required this.label,
    required this.description,
    required this.isDark,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? accentColor.withAlpha(40) : accentColor.withAlpha(25))
            : (isDark ? const Color(0xFF1B1A30) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(18)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? accentColor.withAlpha(isDark ? 80 : 50)
                : accentColor.withAlpha(isDark ? 25 : 12),
            blurRadius: isSelected ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
// SLIDE 4: Create, Replay & Daily Puzzles - Interactive Scrubber & Features!
// ---------------------------------------------------------------------------
class _ReplayAndFeaturesSlide extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;
  final bool isReplay;

  const _ReplayAndFeaturesSlide({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
    this.isReplay = false,
  });

  @override
  State<_ReplayAndFeaturesSlide> createState() => _ReplayAndFeaturesSlideState();
}

class _ReplayAndFeaturesSlideState extends State<_ReplayAndFeaturesSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _replayController;

  bool _isPlaying = true;
  double _scrubProgress = 0.0;
  bool _isScrubbing = false;

  @override
  void initState() {
    super.initState();
    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _replayController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _replayController.repeat();
      } else {
        _replayController.stop();
      }
    });
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
        final progress = _isScrubbing ? _scrubProgress : _replayController.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Replay Showcase Mockup
            Container(
              width: 255,
              height: 155,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF19182C) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.primaryColor.withAlpha(widget.isDark ? 80 : 40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withAlpha(widget.isDark ? 50 : 25),
                    blurRadius: 20,
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
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ED573).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2ED573).withAlpha(80)),
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
                          duration: const Duration(milliseconds: 140),
                          width: 24,
                          height: 52,
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

                  // Progress Scrubber Bar & Controls
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 20,
                          color: widget.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: widget.primaryColor,
                              inactiveTrackColor: widget.isDark ? Colors.white12 : Colors.black12,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (val) {
                                setState(() {
                                  _isScrubbing = true;
                                  _scrubProgress = val;
                                });
                              },
                              onChangeEnd: (val) {
                                setState(() {
                                  _isScrubbing = false;
                                });
                                _replayController.forward(from: val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(isDark ? 30 : 15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  // Interactive Visual Card
                  child,
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 8),

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
                  const SizedBox(height: 6),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.38,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white70 : Colors.black87.withAlpha(180),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
