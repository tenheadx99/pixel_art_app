import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_style.dart';

/// A reusable, playful "you earned something" dialog used across the game
/// layer (level-ups, milestone gifts, achievements, doubled rewards). Matches
/// the completion-HUD card look: gradient card, a bouncing badge, an optional
/// diamond amount, and a single dismiss button.
Future<void> showRewardPopup(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  int? diamonds,
  String buttonLabel = 'Awesome!',
  List<Color> badgeColors = const [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(150),
    builder: (_) => _RewardPopupCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      diamonds: diamonds,
      buttonLabel: buttonLabel,
      badgeColors: badgeColors,
    ),
  );
}

class _RewardPopupCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final int? diamonds;
  final String buttonLabel;
  final List<Color> badgeColors;

  const _RewardPopupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.diamonds,
    required this.buttonLabel,
    required this.badgeColors,
  });

  @override
  State<_RewardPopupCard> createState() => _RewardPopupCardState();
}

class _RewardPopupCardState extends State<_RewardPopupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _badgeScale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A2440), const Color(0xFF1B1830)]
                : [Colors.white, const Color(0xFFF3F0FF)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppStyle.primary.withAlpha(70), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _badgeScale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.badgeColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.badgeColors.last.withAlpha(140),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: subColor),
              ),
            ],
            if (widget.diamonds != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9D2E).withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      color: Color(0xFFFF9D2E),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${widget.diamonds}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
