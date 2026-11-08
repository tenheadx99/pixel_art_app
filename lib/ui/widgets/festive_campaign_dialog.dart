import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/festive_campaign.dart';

/// Shows a dynamic festive or seasonal campaign celebration dialog.
Future<void> showFestiveCampaignDialog(
  BuildContext context, {
  required FestiveCampaign campaign,
  required VoidCallback onClaim,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => _FestiveDialogCard(
      campaign: campaign,
      onClaim: onClaim,
    ),
  );
}

class _FestiveDialogCard extends StatefulWidget {
  final FestiveCampaign campaign;
  final VoidCallback onClaim;

  const _FestiveDialogCard({
    required this.campaign,
    required this.onClaim,
  });

  @override
  State<_FestiveDialogCard> createState() => _FestiveDialogCardState();
}

class _FestiveDialogCardState extends State<_FestiveDialogCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
    );
    _ctrl.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Color> _gradientForTheme(String theme) {
    switch (theme.toLowerCase()) {
      case 'crimson':
        return const [Color(0xFFE63946), Color(0xFF9D0208)];
      case 'purple':
        return const [Color(0xFF7209B7), Color(0xFF3A0CA3)];
      case 'spring':
        return const [Color(0xFF06D6A0), Color(0xFF118AB2)];
      case 'cyber':
        return const [Color(0xFF4CC9F0), Color(0xFF4361EE)];
      case 'sunset':
        return const [Color(0xFFFF5964), Color(0xFFFA9500)];
      case 'gold':
      default:
        return const [Color(0xFFFFB703), Color(0xFFFB8500)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradient = _gradientForTheme(widget.campaign.themeGradient);

    return ScaleTransition(
      scale: _scale,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F222A) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withAlpha(90),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Festive Gradient Header with Emoji
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(120),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.campaign.emoji,
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.campaign.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (widget.campaign.message.isNotEmpty) ...[
                      Text(
                        widget.campaign.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: isDark
                              ? Colors.white.withAlpha(210)
                              : const Color(0xFF4A4E69),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Reward badge if bonus diamonds > 0
                    if (widget.campaign.rewardDiamonds > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C303E)
                              : const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFD24C),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              '+${widget.campaign.rewardDiamonds} Free Diamonds!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark
                                    ? const Color(0xFFFFD24C)
                                    : const Color(0xFF856404),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Claim / Action button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gradient.first,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: gradient.first.withAlpha(120),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onClaim();
                        },
                        child: Text(
                          widget.campaign.buttonLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : Colors.black.withAlpha(120),
                          fontSize: 14,
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

