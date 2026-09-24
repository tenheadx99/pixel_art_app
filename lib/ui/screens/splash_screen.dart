import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/flavor.dart';
import '../motion.dart';

class SplashScreen extends StatefulWidget {
  final bool canContinue;
  final Duration displayDuration;
  final String loadingMessage;
  final VoidCallback? onFinished;

  const SplashScreen({
    super.key,
    this.canContinue = false,
    this.displayDuration = const Duration(seconds: 2),
    this.loadingMessage = 'Loading...',
    this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _ambientController;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  static final List<_PixelParticle> _particles = () {
    final rng = Random(42);
    return List.generate(24, (i) {
      return _PixelParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 4.0 + rng.nextDouble() * 5.5,
        speed: 0.5 + rng.nextDouble() * 0.7,
        opacity: 0.14 + rng.nextDouble() * 0.28,
        oscillation: 6.0 + rng.nextDouble() * 10.0,
      );
    });
  }();

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Motion.settle),
      ),
    );

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Motion.standard),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    if (widget.canContinue) {
      Future.delayed(widget.displayDuration, () {
        if (mounted) widget.onFinished?.call();
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.current;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: flavor.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // 1. Ambient Floating Pixel Dust Particles
                AnimatedBuilder(
                  animation: _ambientController,
                  builder: (context, _) {
                    return Stack(
                      children: _particles.map((p) {
                        final t = (_ambientController.value * p.speed) % 1.0;
                        final currentY = ((p.y - t) % 1.0) * maxHeight;
                        final currentX = (p.x * maxWidth) +
                            sin((t + p.x) * 2 * pi) * p.oscillation;

                        return Positioned(
                          left: currentX,
                          top: currentY,
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withAlpha((p.opacity * 255).round()),
                              borderRadius: BorderRadius.circular(1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white
                                      .withAlpha((p.opacity * 110).round()),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // 2. Centered Content (Icon, Titles, Pixel Loader)
                Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Icon with Breathing Glow Halo & Specular Shimmer Sweep
                          ScaleTransition(
                            scale: _iconScale,
                            child: FadeTransition(
                              opacity: _iconFade,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Breathing Ambient Glow Halo
                                  AnimatedBuilder(
                                    animation: _ambientController,
                                    builder: (context, _) {
                                      final pulse = sin(
                                        _ambientController.value * 2 * pi,
                                      );
                                      final haloScale = 1.06 + 0.08 * pulse;
                                      final haloAlpha =
                                          (75 + 40 * pulse).clamp(25, 120).toInt();

                                      return Transform.scale(
                                        scale: haloScale,
                                        child: Container(
                                          width: 132,
                                          height: 132,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(36),
                                            boxShadow: [
                                              BoxShadow(
                                                color: flavor.accent
                                                    .withAlpha(haloAlpha),
                                                blurRadius: 36,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // Icon Box + Diagonal Shimmer Glint
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(45),
                                          blurRadius: 28,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withAlpha(90),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Stack(
                                        children: [
                                          Image.asset(
                                            flavor.appIconPath,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                          // Periodic Specular Light Sweep
                                          Positioned.fill(
                                            child: AnimatedBuilder(
                                              animation: _ambientController,
                                              builder: (context, _) {
                                                final cycle =
                                                    _ambientController.value;
                                                // Sweep runs during first 40% of cycle
                                                if (cycle > 0.40) {
                                                  return const SizedBox.shrink();
                                                }
                                                final progress = cycle / 0.40;
                                                final slide =
                                                    -1.4 + progress * 2.8;

                                                return Transform.translate(
                                                  offset: Offset(
                                                    slide * 90,
                                                    slide * 90,
                                                  ),
                                                  child: Transform.rotate(
                                                    angle: -pi / 4,
                                                    child: Container(
                                                      width: 38,
                                                      height: 220,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            Colors.white
                                                                .withAlpha(0),
                                                            Colors.white
                                                                .withAlpha(140),
                                                            Colors.white
                                                                .withAlpha(0),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Splash Title
                          SlideTransition(
                            position: _titleSlide,
                            child: FadeTransition(
                              opacity: _titleFade,
                              child: Text(
                                flavor.splashTitle,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Splash Tagline
                          FadeTransition(
                            opacity: _taglineFade,
                            child: Text(
                              flavor.splashTagline,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withAlpha(210),
                                letterSpacing: 4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 44),

                          // Custom Pixel Loading Indicator & Status
                          FadeTransition(
                            opacity: _loaderFade,
                            child: AnimatedBuilder(
                              animation: _ambientController,
                              builder: (context, _) {
                                return Column(
                                  children: [
                                    _PixelDotsLoader(
                                      animationValue: _ambientController.value,
                                      activeColor: flavor.accent,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      widget.loadingMessage,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withAlpha(175),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PixelParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double oscillation;

  const _PixelParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.oscillation,
  });
}

class _PixelDotsLoader extends StatelessWidget {
  final double animationValue;
  final Color activeColor;

  const _PixelDotsLoader({
    required this.animationValue,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    const dotCount = 4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dotCount, (index) {
        // Sequentially staggered sine wave
        final phase = (animationValue * 2 * pi) - (index * 0.7);
        final normalized = (sin(phase) + 1.0) / 2.0; // 0.0 to 1.0
        final bounceOffset = -7.0 * normalized;
        final scale = 0.85 + 0.3 * normalized;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.5),
          child: Transform.translate(
            offset: Offset(0, bounceOffset),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white.withAlpha(150),
                    activeColor,
                    normalized,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withAlpha((normalized * 150).round()),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
