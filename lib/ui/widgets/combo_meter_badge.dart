import 'package:flutter/material.dart';

/// A floating HUD combo badge that tracks streak fills with elastic bounce,
/// tier colors (Amber -> Hot Orange -> Electric Cyan -> Ultra Magenta -> Zen Overdrive Gold),
/// and a mini streak progress bar.
class ComboMeterBadge extends StatefulWidget {
  final int combo;
  final bool isOverdrive;

  const ComboMeterBadge({
    super.key,
    required this.combo,
    this.isOverdrive = false,
  });

  @override
  State<ComboMeterBadge> createState() => _ComboMeterBadgeState();
}

class _ComboMeterBadgeState extends State<ComboMeterBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant ComboMeterBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.combo > oldWidget.combo && widget.combo >= 3) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.combo >= 3;
    final combo = widget.combo;
    final isOverdrive = widget.isOverdrive || combo >= 30;

    // Calculate progress towards next milestone
    final double tierProgress;
    final String tierTitle;
    final Color tierColor;
    final Color glowColor;
    final IconData iconData;

    if (isOverdrive) {
      tierTitle = 'OVERDRIVE';
      tierColor = const Color(0xFFFFD700);
      glowColor = const Color(0xFFFF007F);
      iconData = Icons.electric_bolt_rounded;
      tierProgress = 1.0;
    } else if (combo >= 20) {
      tierTitle = 'ULTRA';
      tierColor = const Color(0xFFFF4081);
      glowColor = const Color(0xFFFF9100);
      iconData = Icons.whatshot_rounded;
      tierProgress = ((combo - 20) / 10).clamp(0.0, 1.0);
    } else if (combo >= 10) {
      tierTitle = 'SUPER';
      tierColor = const Color(0xFF00E5FF);
      glowColor = const Color(0xFF7C4DFF);
      iconData = Icons.flash_on_rounded;
      tierProgress = ((combo - 10) / 10).clamp(0.0, 1.0);
    } else if (combo >= 5) {
      tierTitle = 'HOT';
      tierColor = const Color(0xFFFF9100);
      glowColor = const Color(0xFFFFD700);
      iconData = Icons.local_fire_department_rounded;
      tierProgress = ((combo - 5) / 5).clamp(0.0, 1.0);
    } else {
      tierTitle = 'COMBO';
      tierColor = const Color(0xFFFFB300);
      glowColor = const Color(0xFFFF9100);
      iconData = Icons.local_fire_department_rounded;
      tierProgress = ((combo - 3) / 2).clamp(0.0, 1.0);
    }

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      child: AnimatedScale(
        scale: isVisible ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _pulseScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseScale.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tierColor.withValues(alpha: isOverdrive ? 0.95 : 0.75),
                width: isOverdrive ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: isOverdrive ? 0.6 : 0.35),
                  blurRadius: isOverdrive ? 14 : 8,
                  spreadRadius: isOverdrive ? 2 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconData,
                      size: 15,
                      color: tierColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'x$combo',
                      style: TextStyle(
                        color: tierColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tierTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                if (!isOverdrive) ...[
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 58,
                      height: 3,
                      child: LinearProgressIndicator(
                        value: tierProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

