import 'package:flutter/material.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';
import 'package:pixel_art_app/data/services/app_config_service.dart';

/// An in-feed update announcement card displayed on the Home screen above the
/// Daily Pixel / Streak banner. Features an expandable "What's New" accordion,
/// dynamic release highlights, one-tap store update, and session-only dismissal.
class InAppUpdateCard extends StatefulWidget {
  const InAppUpdateCard({super.key});

  @override
  State<InAppUpdateCard> createState() => _InAppUpdateCardState();
}

class _InAppUpdateCardState extends State<InAppUpdateCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isDismissing = false;
  bool _hasLoggedShown = false;

  late final AnimationController _expandController;
  late final Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _chevronAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _dismiss(AppConfigService configService) {
    if (_isDismissing) return;
    AnalyticsService().logInAppUpdateCardDismissed(
      version: configService.targetVersion,
    );
    setState(() => _isDismissing = true);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        configService.dismissForSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final configService = AppConfigService();

    return AnimatedBuilder(
      animation: configService,
      builder: (context, _) {
        if (!configService.shouldShowUpdateCard) {
          return const SizedBox.shrink();
        }

        if (!_hasLoggedShown) {
          _hasLoggedShown = true;
          AnalyticsService().logForceUpdateShown(
            minVersion: configService.targetVersion,
          );
          AnalyticsService().logInAppUpdateCardShown(
            version: configService.targetVersion,
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final flavor = FlavorConfig.current;
        final brandGradient = flavor.brandGradient.length >= 2
            ? flavor.brandGradient
            : [const Color(0xFF8A2BE2), const Color(0xFF4A00E0)];

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: _isDismissing
              ? const SizedBox(width: double.infinity, height: 0)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF1E1730),
                                const Color(0xFF141224),
                              ]
                            : [
                                const Color(0xFFF7F3FF),
                                const Color(0xFFECE5FF),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: brandGradient[0].withValues(alpha: isDark ? 0.35 : 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brandGradient[0].withValues(alpha: isDark ? 0.20 : 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Header: Rocket badge, Title, Version chip, Dismiss '✕'
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Glowing Rocket / Sparkle icon
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: brandGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: brandGradient[0].withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.rocket_launch_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title & Version tag
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              configService.updateTitle,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1E1730),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (configService.targetVersion.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: brandGradient[0].withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: brandGradient[0].withValues(alpha: 0.35),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'v${configService.targetVersion}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: brandGradient[0],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'A fresh update is ready with new content and improvements!',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.25,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.7)
                                              : const Color(0xFF5E5475),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Dismiss '✕' button
                                InkWell(
                                  onTap: () => _dismiss(configService),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : const Color(0xFF6E6482),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // "What's New" Accordion Header
                          InkWell(
                            onTap: _toggleExpanded,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 15,
                                    color: brandGradient[0],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "See What's New",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: brandGradient[0],
                                    ),
                                  ),
                                  const Spacer(),
                                  RotationTransition(
                                    turns: _chevronAnimation,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: brandGradient[0],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Collapsible "What's New" Content
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 240),
                            crossFadeState: _isExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Container(
                              margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: configService.releaseNotesList.map((note) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 4, right: 8),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: brandGradient[0],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            note,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.3,
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.85)
                                                  : const Color(0xFF2E2445),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                          // Action Buttons: "Update Now" + "Maybe Later"
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: Row(
                              children: [
                                // "Maybe Later" button
                                TextButton(
                                  onPressed: () => _dismiss(configService),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF706485),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Maybe Later',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // "Update Now" Action Button
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: brandGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: brandGradient[0].withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        AnalyticsService().logForceUpdateClicked(
                                          updateUrl: configService.updateUrl,
                                        );
                                        AnalyticsService().logInAppUpdateCardClicked(
                                          updateUrl: configService.updateUrl,
                                        );
                                        configService.launchStore();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.system_update_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Update Now',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
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
        );
      },
    );
  }
}
