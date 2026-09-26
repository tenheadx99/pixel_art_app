import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (!context.mounted) return;
    final adService = context.read<AdService>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    // Fallback/Simulated reward if ads are disabled or in debug/testing scenarios
    // so that the feature is fully testable.
    if (AppConfig.disableAds || !AppConfig.showAds) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('[Simulated Ad] Refilling $toolName...'),
          duration: const Duration(milliseconds: 500),
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          onRefilled();
          messenger?.showSnackBar(
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
        if (context.mounted) {
          onRefilled();
          messenger?.showSnackBar(
            SnackBar(
              content: Text('+1 $toolName refilled!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onUnavailable: () {
        if (context.mounted) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('No ad available right now — try again later.'),
            ),
          );
        }
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
        onWatchAd: (_, toolName, onRefilled) {
          _watchAdRefill(context, toolName, onRefilled);
        },
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
        onWatchAd: (_, toolName, onRefilled) {
          _watchAdRefill(context, toolName, onRefilled);
        },
      ),
    );
  }

  void _showOutOfHintsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OutOfHintsDialog(
        provider: provider,
        settings: settings,
        onWatchAd: (_, toolName, onRefilled) {
          _watchAdRefill(context, toolName, onRefilled);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMulti = provider.brushSize > 1;
    final isPaintActive = !provider.isEraseMode && !provider.isMagicWandMode && !provider.isBombMode;
    final bombActive = provider.isBombMode;
    final wandActive = provider.isMagicWandMode;

    final bombsCount = provider.bombsCount;
    final magicWandsCount = provider.magicWandsCount;
    final hintsAvailable = settings.hintsAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Single / Multi Gem Cell Tool (Ad-free toggle between 1x1 single and 3x3 multi)
          _ToolCircleButton(
            icon: SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(
                painter: MultiCellIconPainter(
                  isMulti: isMulti,
                  isDark: isDark,
                  activeColor: const Color(0xFFE91E63),
                ),
              ),
            ),
            badgeValue: isMulti ? '3x3' : '1x',
            badgeColor: isMulti
                ? const Color(0xFFE91E63)
                : (isDark ? const Color(0xFF4A4E69) : Colors.grey.shade600),
            isActive: isPaintActive && isMulti,
            onTap: () {
              if (provider.isEraseMode || provider.isMagicWandMode || provider.isBombMode) {
                if (provider.isEraseMode) provider.toggleEraseMode();
                if (provider.isMagicWandMode) provider.toggleMagicWandMode();
                if (provider.isBombMode) provider.toggleBombMode();
              }
              final nextSize = provider.brushSize > 1 ? 1 : 3;
              provider.setBrushSize(nextSize);
              HapticFeedback.selectionClick();
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

          // 3. Paint Bucket (Fill all cells of target number across artwork)
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

          // 4. Hint (Lightbulb) Tool
          _ToolCircleButton(
            icon: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFFFB300),
              size: 24,
            ),
            badgeValue: hintsAvailable == 0 ? 'ad' : '$hintsAvailable',
            badgeColor: hintsAvailable == 0
                ? const Color(0xFFFF9800)
                : const Color(0xFFFFA000),
            isActive: false,
            onTap: () {
              if (hintsAvailable == 0) {
                _showOutOfHintsDialog(context);
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
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _ToolCircleButton({
    required this.icon,
    required this.badgeValue,
    required this.isActive,
    this.badgeColor,
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
            width: 52,
            height: 52,
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
                color: badgeColor ?? (isAd ? Colors.blue : Colors.orange),
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

class MultiCellIconPainter extends CustomPainter {
  final bool isMulti;
  final bool isDark;
  final Color activeColor;

  const MultiCellIconPainter({
    required this.isMulti,
    required this.isDark,
    this.activeColor = Colors.pinkAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 5.6;
    const gap = 1.8;
    const totalW = 3 * cellSize + 2 * gap;
    final startX = (size.width - totalW) / 2;
    final startY = (size.height - totalW) / 2;

    final fillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(45) : Colors.black.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final faintFillPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)
      ..style = PaintingStyle.fill;

    final glintPaint = Paint()
      ..color = Colors.white.withAlpha(210)
      ..style = PaintingStyle.fill;

    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final x = startX + c * (cellSize + gap);
        final y = startY + r * (cellSize + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          const Radius.circular(1.5),
        );
        final isCenter = r == 1 && c == 1;

        if (isMulti || isCenter) {
          canvas.drawRRect(rect, fillPaint);
          // Facet glint in top-left
          canvas.drawCircle(Offset(x + 1.6, y + 1.6), 0.7, glintPaint);
        } else {
          // Unselected outer cells when in single-gem mode
          canvas.drawRRect(rect, faintFillPaint);
          canvas.drawRRect(rect, outlinePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MultiCellIconPainter oldDelegate) =>
      isMulti != oldDelegate.isMulti ||
      isDark != oldDelegate.isDark ||
      activeColor != oldDelegate.activeColor;
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
}List<int> _buildBoosterPresets(int maxAffordable) {
  if (maxAffordable <= 1) return [];
  final presets = <int>[1];
  if (maxAffordable <= 4) {
    for (var i = 2; i <= maxAffordable; i++) {
      presets.add(i);
    }
  } else if (maxAffordable <= 7) {
    presets.addAll([2, 3, 5]);
    if (!presets.contains(maxAffordable)) presets.add(maxAffordable);
  } else {
    presets.addAll([3, 5, 10]);
    if (!presets.contains(maxAffordable)) presets.add(maxAffordable);
  }
  return (presets.where((p) => p <= maxAffordable).toSet().toList()..sort());
}

class _StepIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isDark;

  const _StepIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? accentColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? (isDark ? Colors.white : accentColor)
              : (isDark ? Colors.white24 : Colors.black26),
        ),
      ),
    );
  }
}

class _DiamondQuantityRefillCard extends StatefulWidget {
  final String itemSingular;
  final String itemPlural;
  final int unitCost;
  final int currentDiamonds;
  final Color accentColor;
  final bool isDark;
  final void Function(int count) onBuy;

  const _DiamondQuantityRefillCard({
    required this.itemSingular,
    required this.itemPlural,
    required this.unitCost,
    required this.currentDiamonds,
    required this.accentColor,
    required this.isDark,
    required this.onBuy,
  });

  @override
  State<_DiamondQuantityRefillCard> createState() => _DiamondQuantityRefillCardState();
}

class _DiamondQuantityRefillCardState extends State<_DiamondQuantityRefillCard> {
  int _count = 1;

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxAffordable = (widget.currentDiamonds / widget.unitCost).floor();
    if (maxAffordable < 1) return const SizedBox.shrink();

    final clampedCount = _count.clamp(1, maxAffordable);
    final totalCost = clampedCount * widget.unitCost;
    final presets = _buildBoosterPresets(maxAffordable);
    final formattedBalance = _formatNumber(widget.currentDiamonds);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0E2232) : const Color(0xFFF2F9FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: widget.isDark ? 0.38 : 0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: widget.isDark ? 0.16 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Diamond Icon + Info + Stepper
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('💎', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Instant Refill',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : const Color(0xFF171A21),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Balance: $formattedBalance 💎',
                      style: TextStyle(
                        color: widget.isDark
                            ? Colors.cyanAccent.withValues(alpha: 0.85)
                            : const Color(0xFF00838F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Stepper: [-]  count  [+]
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepIconButton(
                      icon: Icons.remove_rounded,
                      enabled: clampedCount > 1,
                      onTap: () {
                        setState(() {
                          _count = (clampedCount - 1).clamp(1, maxAffordable);
                        });
                      },
                      accentColor: widget.accentColor,
                      isDark: widget.isDark,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 26),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$clampedCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: widget.isDark ? Colors.white : const Color(0xFF171A21),
                        ),
                      ),
                    ),
                    _StepIconButton(
                      icon: Icons.add_rounded,
                      enabled: clampedCount < maxAffordable,
                      onTap: () {
                        setState(() {
                          _count = (clampedCount + 1).clamp(1, maxAffordable);
                        });
                      },
                      accentColor: widget.accentColor,
                      isDark: widget.isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Preset Chips
          if (presets.length > 1) ...[
            const SizedBox(height: 9),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: presets.map((p) {
                  final isSelected = p == clampedCount;
                  final isMax = p == maxAffordable;
                  final label = isMax && p > 1 ? '${p}x (Max)' : '${p}x';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _count = p);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accentColor
                              : (widget.isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isSelected
                                ? widget.accentColor
                                : (widget.isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08)),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (widget.isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action Button
          PressableScale(
            onTap: () => widget.onBuy(clampedCount),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.accentColor,
                    Color.lerp(widget.accentColor, Colors.indigoAccent, 0.35)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Get $clampedCount ${clampedCount == 1 ? widget.itemSingular : widget.itemPlural}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCost 💎',
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
      ),
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  final bool isDark;

  const _DialogCloseButton({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop();
        },
        radius: 22,
        containedInkWell: true,
        splashColor: isDark ? Colors.white24 : Colors.black12,
        highlightColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 19,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cost = EconomyConfigService().currentConfig.diamondCostBomb;
    final currentDiamonds = settings.diamondsAvailable;
    final hasEnoughDiamonds = currentDiamonds >= cost;

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

              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

                      // Option 2: INSTANT DIAMOND REFILL CARD WITH MULTI-QUANTITY CONVERTER
                      if (hasEnoughDiamonds) ...[
                        const SizedBox(height: 10),
                        _DiamondQuantityRefillCard(
                          itemSingular: 'Bomb',
                          itemPlural: 'Bombs',
                          unitCost: cost,
                          currentDiamonds: currentDiamonds,
                          accentColor: const Color(0xFF00B0FF),
                          isDark: isDark,
                          onBuy: (count) {
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            Navigator.of(context).pop();
                            if (provider.buyBombWithDiamonds(settings, count: count)) {
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Used ${cost * count} 💎 for $count Bomb${count > 1 ? 's' : ''}! Bomb mode active.',
                                  ),
                                  backgroundColor: const Color(0xFF00897B),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
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
              ),
              // Pinned top-right close button (always on top of scroll view)
              Positioned(
                top: 10,
                right: 10,
                child: _DialogCloseButton(isDark: isDark),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cost = EconomyConfigService().currentConfig.diamondCostWand;
    final currentDiamonds = settings.diamondsAvailable;
    final hasEnoughDiamonds = currentDiamonds >= cost;

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
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF171A21),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEBF3FC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2B3A58) : const Color(0xFFCCE2F9),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎨', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Fills all cells of a number across the artwork',
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
                        _DiamondQuantityRefillCard(
                          itemSingular: 'Paint Bucket',
                          itemPlural: 'Paint Buckets',
                          unitCost: cost,
                          currentDiamonds: currentDiamonds,
                          accentColor: const Color(0xFF2196F3),
                          isDark: isDark,
                          onBuy: (count) {
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            Navigator.of(context).pop();
                            if (provider.buyWandWithDiamonds(settings, count: count)) {
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Used ${cost * count} 💎 for $count Paint Bucket${count > 1 ? 's' : ''}! Fill mode active.',
                                  ),
                                  backgroundColor: const Color(0xFF2196F3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
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
              ),
              // Pinned top-right close button (always on top of scroll view)
              Positioned(
                top: 10,
                right: 10,
                child: _DialogCloseButton(isDark: isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutOfHintsDialog extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final void Function(BuildContext, String, VoidCallback) onWatchAd;

  const _OutOfHintsDialog({
    required this.provider,
    required this.settings,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final economy = EconomyConfigService().currentConfig;
    final cost = max(10, (economy.diamondCostHint / 3).round());
    final currentDiamonds = settings.diamondsAvailable;
    final hasEnoughDiamonds = currentDiamonds >= cost;

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
                          const Color(0xFFFFB300).withValues(alpha: isDark ? 0.35 : 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
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
                            colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lightbulb_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Out of Hints!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF171A21),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2516) : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF4E3D18) : const Color(0xFFFFE082),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Reveals & colors the next cell automatically',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFFFE082)
                                      : const Color(0xFFE65100),
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
                          onWatchAd(context, 'Hint', () {
                            settings.addHints(1);
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
                                Color(0xFFFFB300),
                                Color(0xFFF57C00),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withValues(alpha: 0.38),
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
                                  color: Colors.white.withValues(alpha: 0.25),
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
                                      'Earn +1 Hint',
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
                                    color: Color(0xFFE65100),
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
                      // Option 2: INSTANT DIAMOND REFILL CARD WITH MULTI-QUANTITY CONVERTER
                      if (hasEnoughDiamonds) ...[
                        const SizedBox(height: 10),
                        _DiamondQuantityRefillCard(
                          itemSingular: 'Hint',
                          itemPlural: 'Hints',
                          unitCost: cost,
                          currentDiamonds: currentDiamonds,
                          accentColor: const Color(0xFFFF9800),
                          isDark: isDark,
                          onBuy: (count) {
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            Navigator.of(context).pop();
                            final totalCost = cost * count;
                            if (settings.useDiamonds(totalCost)) {
                              settings.addHints(count);
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Used $totalCost 💎 for $count Hint${count > 1 ? 's' : ''}! 💡',
                                  ),
                                  backgroundColor: const Color(0xFFFF9800),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
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
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _DialogCloseButton(isDark: isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
