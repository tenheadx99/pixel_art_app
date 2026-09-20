import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../data/services/ad_service.dart';
import '../../config/app_config.dart';
import '../theme/app_style.dart';
import '../../data/services/economy_config_service.dart';
import 'diamond_shop_sheet.dart';
import 'pressable.dart';

class NumberToolbar extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final VoidCallback? onHint;

  const NumberToolbar({
    super.key,
    required this.provider,
    required this.settings,
    this.onHint,
  });

  void _watchAdRefill(BuildContext context, String toolName, VoidCallback onRefilled) {
    final adService = context.read<AdService>();

    // Fallback/Simulated reward if ads are disabled or in debug/testing scenarios
    // so that the feature is fully testable.
    if (AppConfig.disableAds || !AppConfig.showAds) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[Simulated Ad] Refilling $toolName...'),
          duration: const Duration(milliseconds: 500),
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          onRefilled();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+1 $toolName refilled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
      return;
    }

    adService.showRewardedAd(
      placement: 'refill_${toolName.toLowerCase().replaceAll(' ', '_')}',
      onRewarded: () {
        onRefilled();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+1 $toolName refilled!'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onUnavailable: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ad available right now — try again later.'),
          ),
        );
      },
    );
  }

  void _showOutOfBombsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OutOfBombsDialog(
        provider: provider,
        settings: settings,
        onWatchAd: _watchAdRefill,
      ),
    );
  }

  void _showOutOfWandsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OutOfWandsDialog(
        provider: provider,
        settings: settings,
        onWatchAd: _watchAdRefill,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brushActive = !provider.isEraseMode && !provider.isMagicWandMode && !provider.isBombMode;
    final bombActive = provider.isBombMode;
    final wandActive = provider.isMagicWandMode;

    final brushesCount = provider.brushesCount;
    final bombsCount = provider.bombsCount;
    final magicWandsCount = provider.magicWandsCount;
    final hintsAvailable = settings.hintsAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Paintbrush Tool (Cycles brush size: 1, 2, 3)
          _ToolCircleButton(
            icon: const Icon(
              Icons.brush_rounded,
              color: Colors.pinkAccent,
              size: 24,
            ),
            badgeValue: brushesCount == 0 ? 'ad' : '$brushesCount',
            isActive: brushActive,
            onTap: () {
              if (brushesCount == 0) {
                _watchAdRefill(context, 'Brush', () => provider.addBrushes(1));
              } else {
                final nextSize = provider.brushSize == 3 ? 1 : provider.brushSize + 1;
                provider.setBrushSize(nextSize);
                if (provider.isEraseMode || provider.isMagicWandMode || provider.isBombMode) {
                  if (provider.isEraseMode) provider.toggleEraseMode();
                  if (provider.isMagicWandMode) provider.toggleMagicWandMode();
                  if (provider.isBombMode) provider.toggleBombMode();
                }
              }
            },
          ),

          // 2. Bomb Tool (Fills 11-cell circular area)
          _ToolCircleButton(
            icon: SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(
                painter: const BombIconPainter(),
              ),
            ),
            badgeValue: bombsCount == 0 ? 'ad' : '$bombsCount',
            isActive: bombActive,
            onTap: () {
              if (bombsCount == 0) {
                _showOutOfBombsDialog(context);
              } else {
                provider.toggleBombMode();
              }
            },
          ),

          // 3. Paint Bucket (Contiguous magic wand fill)
          _ToolCircleButton(
            icon: const Icon(
              Icons.format_color_fill_rounded,
              color: Colors.blueAccent,
              size: 24,
            ),
            badgeValue: magicWandsCount == 0 ? 'ad' : '$magicWandsCount',
            isActive: wandActive,
            onTap: () {
              if (magicWandsCount == 0) {
                _showOutOfWandsDialog(context);
              } else {
                provider.toggleMagicWandMode();
              }
            },
          ),

          // 4. Hint (Lightbulb)
          _ToolCircleButton(
            icon: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.orangeAccent,
              size: 24,
            ),
            badgeValue: hintsAvailable == 0 ? 'ad' : '$hintsAvailable',
            isActive: false,
            onTap: () {
              if (hintsAvailable == 0) {
                _watchAdRefill(context, 'Hint', () => settings.addHints(1));
              } else {
                onHint?.call();
              }
            },
          ),

          // 5. Diamond Shop Button
          _ToolCircleButton(
            icon: Icon(
              Icons.diamond_rounded,
              color: Colors.cyanAccent.shade400,
              size: 24,
            ),
            badgeValue: 'Shop',
            isActive: false,
            onTap: () {
              DiamondShopSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ToolCircleButton extends StatelessWidget {
  final Widget icon;
  final String badgeValue;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToolCircleButton({
    required this.icon,
    required this.badgeValue,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAd = badgeValue == 'ad';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      scale: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? AppStyle.primary.withAlpha(70) : AppStyle.primary.withAlpha(35))
                  : (isDark ? Colors.white.withAlpha(15) : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppStyle.primary : (isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? AppStyle.primary.withAlpha(60)
                      : (isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(15)),
                  blurRadius: isActive ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: icon,
            ),
          ),
          // Orange Badge in Top Right (or Blue for ad refills)
          Positioned(
            top: isAd ? -4 : -2,
            right: isAd ? -6 : -2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isAd ? 6 : 4,
                vertical: isAd ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: isAd ? Colors.blue : Colors.orange,
                borderRadius: BorderRadius.circular(10),
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: isAd ? 24 : 18,
                minHeight: 18,
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
    );
  }
}

class BombIconPainter extends CustomPainter {
  const BombIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(size.width, size.height) * 0.35;

    // Body (dark slate blue)
    final bodyPaint = Paint()
      ..color = const Color(0xFF2E313E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 1, cy + 1), radius, bodyPaint);

    // Body Highlight (white with low opacity)
    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(70)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 1 - radius * 0.3, cy + 1 - radius * 0.3), radius * 0.25, highlightPaint);

    // Fuse cap (grey)
    final capPaint = Paint()
      ..color = const Color(0xFF7E8494)
      ..style = PaintingStyle.fill;
    final capPath = Path()
      ..moveTo(cx - 3, cy - radius + 1)
      ..lineTo(cx + 3, cy - radius + 1)
      ..lineTo(cx + 4, cy - radius - 2)
      ..lineTo(cx - 4, cy - radius - 2)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Fuse wire (grey curve)
    final fusePaint = Paint()
      ..color = const Color(0xFF7E8494)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final fusePath = Path()
      ..moveTo(cx, cy - radius - 2)
      ..quadraticBezierTo(cx + 4, cy - radius - 8, cx + 8, cy - radius - 5);
    canvas.drawPath(fusePath, fusePaint);

    // Fuse spark (orange/yellow star)
    final sparkPaint = Paint()
      ..color = const Color(0xFFFF9E00)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + 8, cy - radius - 5), 2.5, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OutOfBombsDialog extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final void Function(BuildContext, String, VoidCallback) onWatchAd;

  const _OutOfBombsDialog({
    required this.provider,
    required this.settings,
    required this.onWatchAd,
  });

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cost = EconomyConfigService().currentConfig.diamondCostBomb;
    final currentDiamonds = settings.diamondsAvailable;
    final hasEnoughDiamonds = currentDiamonds >= cost;
    final formattedDiamonds = _formatNumber(currentDiamonds);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C202C) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.06),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.16),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Top ambient radial burst glow
              Positioned(
                top: -30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF5722).withValues(alpha: isDark ? 0.3 : 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: subtle close button on top-right
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),

                    // Hero Bomb with Radiant Sunburst & Sparks
                    const SizedBox(
                      width: 96,
                      height: 96,
                      child: CustomPaint(
                        painter: _HeroBombPainter(),
                      ),
                    ),

                    // Super Booster Tag
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.28),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 13,
                            color: Color(0xFFFF5722),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'SUPER BOOSTER',
                            style: TextStyle(
                              color: Color(0xFFFF5722),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    Text(
                      'Out of Bombs!',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF171A21),
                      ),
                    ),

                    // Feature Callout Card
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222736) : const Color(0xFFFFF6F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF333B50) : const Color(0xFFFFE0D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Blasts 11 cells in a circle instantly',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFFFAB91)
                                    : const Color(0xFFD84315),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Option 1: FREE REFILL CARD (Watch Video)
                    PressableScale(
                      onTap: () {
                        Navigator.of(context).pop();
                        onWatchAd(context, 'Bomb', () {
                          provider.addBombs(1);
                          provider.toggleBombMode();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF5722),
                              Color(0xFFFF9100),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5722).withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Watch Video',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 1.5),
                                  Text(
                                    'Earn +1 Paint Bomb',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'FREE 🎁',
                                style: TextStyle(
                                  color: Color(0xFFFF5722),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option 2: INSTANT DIAMOND REFILL CARD (When user has enough diamonds)
                    if (hasEnoughDiamonds) ...[
                      const SizedBox(height: 10),
                      PressableScale(
                        onTap: () {
                          Navigator.of(context).pop();
                          if (provider.buyBombWithDiamonds(settings)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Used $cost 💎 for 1 Bomb! Bomb mode active.',
                                ),
                                backgroundColor: const Color(0xFF00897B),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0D2533)
                                : const Color(0xFFF0F9FB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF00B0FF).withValues(alpha: 0.4)
                                  : const Color(0xFF80DEEA),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00B0FF).withValues(
                                  alpha: isDark ? 0.16 : 0.06,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B0FF).withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('💎', style: TextStyle(fontSize: 19)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Instant Refill',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF004D40),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 1.5),
                                    Text(
                                      'You have $formattedDiamonds 💎',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.cyanAccent.withValues(alpha: 0.8)
                                            : const Color(0xFF00838F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B0FF),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00B0FF).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$cost 💎',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Diamond Shop & Booster Packs Link
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        DiamondShopSheet.show(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Diamond Shop & Booster Packs 💎',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF455A64),
                                decoration: TextDecoration.underline,
                                decorationColor: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                          ],
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
    );
  }
}

class _HeroBombPainter extends CustomPainter {
  const _HeroBombPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // 1. Radiant Sunburst Rays (12 rays)
    final rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.22);
    final rayRadius = size.width * 0.48;
    const rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final a1 = (i * 2 * pi / rayCount) - 0.12;
      final a2 = (i * 2 * pi / rayCount) + 0.12;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + cos(a1) * rayRadius, cy + sin(a1) * rayRadius)
        ..lineTo(cx + cos(a2) * rayRadius, cy + sin(a2) * rayRadius)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // 2. Central Fiery Gradient Sphere / Aura
    final auraPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFB74D),
          Color(0xFFFF7043),
          Color(0xFFE64A19),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.38));
    canvas.drawCircle(center, size.width * 0.38, auraPaint);

    // 3. Ambient Star Sparks around the aura
    final sparkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.9);
    final sparkOffsets = [
      Offset(cx - 30, cy - 26),
      Offset(cx + 32, cy - 22),
      Offset(cx - 32, cy + 18),
      Offset(cx + 30, cy + 22),
      Offset(cx + 4, cy - 36),
    ];
    for (int i = 0; i < sparkOffsets.length; i++) {
      final o = sparkOffsets[i];
      final r = (i % 2 == 0) ? 2.5 : 1.8;
      canvas.drawCircle(o, r, sparkPaint);
    }

    // 4. Bomb Body (Glossy 3D Sphere)
    final bombRadius = size.width * 0.22;
    final bombCenter = Offset(cx - 1, cy + 3);

    // Bomb Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(bombCenter.translate(0, 3), bombRadius, shadowPaint);

    // Bomb Slate Body with 3D gradient
    final bombBodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: [
          Color(0xFF454B5E),
          Color(0xFF262935),
          Color(0xFF161820),
        ],
      ).createShader(Rect.fromCircle(center: bombCenter, radius: bombRadius));
    canvas.drawCircle(bombCenter, bombRadius, bombBodyPaint);

    // Specular Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bombCenter.dx - bombRadius * 0.35, bombCenter.dy - bombRadius * 0.35),
        width: bombRadius * 0.45,
        height: bombRadius * 0.28,
      ),
      highlightPaint,
    );

    // 5. Metal Collar / Neck Cap
    final neckPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA0A7B5), Color(0xFF5F6575)],
      ).createShader(Rect.fromLTWH(cx - 5, bombCenter.dy - bombRadius - 4, 10, 5));
    final neckRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - 1, bombCenter.dy - bombRadius + 1),
        width: 11,
        height: 5,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(neckRRect, neckPaint);

    // 6. Curved Fuse Rope
    final fusePaint = Paint()
      ..color = const Color(0xFFD4A373)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final fusePath = Path()
      ..moveTo(cx - 1, bombCenter.dy - bombRadius - 1)
      ..cubicTo(
        cx + 3,
        bombCenter.dy - bombRadius - 8,
        cx + 10,
        bombCenter.dy - bombRadius - 10,
        cx + 12,
        bombCenter.dy - bombRadius - 6,
      );
    canvas.drawPath(fusePath, fusePaint);

    // 7. Blazing Spark Flame at Fuse Tip
    final tip = Offset(cx + 12, bombCenter.dy - bombRadius - 6);

    // Outer flame glow
    final flameGlow = Paint()
      ..color = const Color(0xFFFF3D00).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(tip, 6.0, flameGlow);

    // Mid yellow flame
    final flameMid = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tip, 3.8, flameMid);

    // Hot white flame core
    final flameCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tip, 2.0, flameCore);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OutOfWandsDialog extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final void Function(BuildContext, String, VoidCallback) onWatchAd;

  const _OutOfWandsDialog({
    required this.provider,
    required this.settings,
    required this.onWatchAd,
  });

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cost = EconomyConfigService().currentConfig.diamondCostWand;
    final currentDiamonds = settings.diamondsAvailable;
    final hasEnoughDiamonds = currentDiamonds >= cost;
    final formattedDiamonds = _formatNumber(currentDiamonds);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C202C) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.black.withValues(alpha: 0.06),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.16),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2196F3).withValues(alpha: isDark ? 0.3 : 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.format_color_fill_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Out of Paint Buckets!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF171A21),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2838) : const Color(0xFFEBF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C3E55) : const Color(0xFFCCE5FF),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎨', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Fills connected cells of a number instantly',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF90CAF9)
                                    : const Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PressableScale(
                      onTap: () {
                        Navigator.of(context).pop();
                        onWatchAd(context, 'Paint Bucket', () {
                          provider.addMagicWands(2);
                          provider.toggleMagicWandMode();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2196F3),
                              Color(0xFF00BCD4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Watch Video',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 1.5),
                                  Text(
                                    'Earn +2 Paint Buckets',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'FREE 🎁',
                                style: TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasEnoughDiamonds) ...[
                      const SizedBox(height: 10),
                      PressableScale(
                        onTap: () {
                          Navigator.of(context).pop();
                          if (provider.buyWandWithDiamonds(settings)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Used $cost 💎 for 1 Paint Bucket! Fill mode active.',
                                ),
                                backgroundColor: const Color(0xFF2196F3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262C3D) : const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF38435C)
                                  : const Color(0xFFD4E0F0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('💎', style: TextStyle(fontSize: 20)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Buy with Diamonds',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF171A21),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1.5),
                                    Text(
                                      '$cost Diamonds · You have $formattedDiamonds',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$cost 💎',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF80D8FF) : const Color(0xFF0091EA),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        DiamondShopSheet.show(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              size: 15,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Diamond Shop & Booster Packs 💎',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF455A64),
                                decoration: TextDecoration.underline,
                                decorationColor: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                          ],
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
    );
  }
}
