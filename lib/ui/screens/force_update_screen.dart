import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/ui/theme/app_style.dart';

class ForceUpdateScreen extends StatefulWidget {
  final String updateUrl;

  const ForceUpdateScreen({
    super.key,
    required this.updateUrl,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _bubbleController;
  late Animation<double> _floatingAnim;
  late Animation<double> _scaleButtonAnim;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    // Floating animation for the update icon
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatingAnim = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _floatingController,
        curve: Curves.easeInOut,
      ),
    );

    // Continuous rotation/drifting for the background bubbles
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _launchUpdateUrl() async {
    String finalUrl = widget.updateUrl;
    if (finalUrl.isEmpty) {
      if (Platform.isAndroid) {
        finalUrl = AppConstants.appStoreUrl;
      } else if (Platform.isIOS) {
        // Fallback for iOS App Store (using the play store ID for the app, but formatted as iOS)
        finalUrl = 'https://apps.apple.com/app/id6475739215'; // Replace with real app ID if available
      } else {
        finalUrl = AppConstants.appStoreUrl;
      }
    }

    final Uri uri = Uri.parse(finalUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback launch
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      // Handle exception gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppStyle.gradientStart,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Animated Floating Bubbles in Background
          ...List.generate(4, (index) => _buildAnimatedBubble(index)),

          // Main Center Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Floating Rocket/Update Icon
                    AnimatedBuilder(
                      animation: _floatingAnim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatingAnim.value),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha(80),
                              Colors.white.withAlpha(20),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.system_update_alt_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Glassmorphic Card containing message and button
                    Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: AppStyle.glassmorphism(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Time to Upgrade!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'A brand new version of Pixely is available. We have added fresh features, speed improvements, and bug fixes to enhance your creative journey.',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white.withAlpha(180)
                                  : Colors.black54,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Interactive Scale-on-Tap Button
                          GestureDetector(
                            onTapDown: (_) => setState(() => _isButtonPressed = true),
                            onTapUp: (_) => setState(() => _isButtonPressed = false),
                            onTapCancel: () => setState(() => _isButtonPressed = false),
                            onTap: _launchUpdateUrl,
                            child: AnimatedScale(
                              scale: _isButtonPressed ? 0.95 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppStyle.headerGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppStyle.primary.withAlpha(100),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Update Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
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
    );
  }

  Widget _buildAnimatedBubble(int index) {
    final random = Random(index);
    final double size = 80.0 + random.nextDouble() * 120;
    final double startLeft = random.nextDouble() * 300;
    final double startTop = random.nextDouble() * 600;

    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, child) {
        // Drifting effect
        final double offset = sin(_bubbleController.value * 2 * pi + index) * 15;
        return Positioned(
          left: startLeft + offset,
          top: startTop - offset,
          child: Opacity(
            opacity: 0.12,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
