import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_style.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.elasticOut)),
    );
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );

    _controller.forward();

    if (widget.canContinue) {
      Future.delayed(widget.displayDuration, () {
        if (mounted) widget.onFinished?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppStyle.gradientStart,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(20, (i) => _buildFloatingBubble(i)),
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: AnimatedBuilder(
                  animation: _scaleAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            colors: [Colors.white.withAlpha(200), Colors.white.withAlpha(100)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.palette,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Pixel Art',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Color by Number',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha(200),
                          letterSpacing: 4,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withAlpha(180),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.loadingMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBubble(int index) {
    final random = Random(index);
    final size = 20.0 + random.nextDouble() * 40;

    return Positioned(
      left: random.nextDouble() * 0.9,
      top: random.nextDouble() * 0.9,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: (0.1 + random.nextDouble() * 0.2) * _controller.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(30),
              ),
            ),
          );
        },
      ),
    );
  }
}
