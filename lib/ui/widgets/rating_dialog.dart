import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/flavor.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/review_service.dart';
import '../theme/app_style.dart';

/// Shows a beautiful, interactive 5-star rating dialog for the app.
Future<void> showRatingDialog(
  BuildContext context, {
  required LocalStorageService storage,
  VoidCallback? onRated,
  VoidCallback? onDismissed,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withAlpha(150),
    barrierDismissible: true,
    builder: (dialogCtx) => _RatingDialogCard(
      storage: storage,
      onRated: onRated,
      onDismissed: onDismissed,
    ),
  ).then((_) {
    // If dismissed by tapping barrier
    onDismissed?.call();
  });
}

class _RatingDialogCard extends StatefulWidget {
  final LocalStorageService storage;
  final VoidCallback? onRated;
  final VoidCallback? onDismissed;

  const _RatingDialogCard({
    required this.storage,
    this.onRated,
    this.onDismissed,
  });

  @override
  State<_RatingDialogCard> createState() => _RatingDialogCardState();
}

class _RatingDialogCardState extends State<_RatingDialogCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  int _selectedStars = 5;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onStarTapped(int rating) {
    HapticFeedback.lightImpact();
    setState(() => _selectedStars = rating);
  }

  Future<void> _submitRating() async {
    if (_submitted) return;
    _submitted = true;
    HapticFeedback.mediumImpact();

    await ReviewService().submitRating(
      storage: widget.storage,
      stars: _selectedStars,
    );

    widget.onRated?.call();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFD24C)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thank you for your review and support! ❤️',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _dismiss() {
    widget.onDismissed?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavor = FlavorConfig.current;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A2440), const Color(0xFF1B1830)]
                : [Colors.white, const Color(0xFFF7F5FF)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppStyle.primary.withAlpha(75),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouncing Star Icon Badge
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9D2E).withAlpha(120),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              'Enjoying ${flavor.appName}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Your review helps us bring you more beautiful pixel artworks to color!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Interactive Star Rating Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isSelected = starNum <= _selectedStars;
                  return GestureDetector(
                    onTap: () => _onStarTapped(starNum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.15 : 1.0,
                        child: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 38,
                          color: isSelected ? const Color(0xFFFFB300) : (isDark ? Colors.white30 : Colors.black26),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Primary Button: Rate on Google Play
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitRating,
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text(
                  'Submit Rating',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppStyle.primary.withAlpha(130),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Button: Maybe Later
            TextButton(
              onPressed: _dismiss,
              style: TextButton.styleFrom(
                foregroundColor: subColor,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              child: const Text(
                'Maybe Later',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
