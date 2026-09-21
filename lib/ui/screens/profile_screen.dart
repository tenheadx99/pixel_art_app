import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/services/local_storage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/gallery_provider.dart';
import '../motion.dart';
import '../theme/app_style.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/diamond_shop_sheet.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable.dart';
import '../widgets/rolling_count.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/transitions.dart';
import 'gallery_screen.dart';

/// Achievement meta description, lore, and rewards.
class _AchievementMeta {
  final String id;
  final String title;
  final String description;
  final String howToUnlock;
  final int diamondsReward;
  final int xpReward;
  final IconData icon;
  final List<Color> gradient;
  final Color shadowColor;

  const _AchievementMeta({
    required this.id,
    required this.title,
    required this.description,
    required this.howToUnlock,
    required this.diamondsReward,
    required this.xpReward,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
  });
}

/// Upgraded Player Profile screen:
/// - Cosmic 3D Level Passport with XP gauge, rank tier, and perks sheet.
/// - Interactive stat tiles with haptics, glow backlights, and context modals.
/// - Rich achievement gallery with unique themed badges, rewards, and celebration confetti.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  static const Map<String, _AchievementMeta> _achievementsData = {
    'complete_first': _AchievementMeta(
      id: 'complete_first',
      title: 'First Masterpiece',
      description: 'Your artistic journey has begun with flying colors!',
      howToUnlock: 'Complete your very first pixel artwork.',
      diamondsReward: 50,
      xpReward: 100,
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFFFF9F43), Color(0xFFFF5252)],
      shadowColor: Color(0xFFFF5252),
    ),
    'fill_10': _AchievementMeta(
      id: 'fill_10',
      title: 'Getting Started',
      description: 'First steps on the canvas — feeling the flow.',
      howToUnlock: 'Color 10 pixels in a single painting session.',
      diamondsReward: 20,
      xpReward: 50,
      icon: Icons.brush_rounded,
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
      shadowColor: Color(0xFF10B981),
    ),
    'fill_100': _AchievementMeta(
      id: 'fill_100',
      title: 'Dedicated Artist',
      description: 'Hours of focus turning empty squares into vibrant art.',
      howToUnlock: 'Color 100 pixels in a single artwork.',
      diamondsReward: 50,
      xpReward: 150,
      icon: Icons.palette_rounded,
      gradient: [Color(0xFF6366F1), Color(0xFF3B82F6)],
      shadowColor: Color(0xFF6366F1),
    ),
    'fill_500': _AchievementMeta(
      id: 'fill_500',
      title: 'Pixel Master',
      description: 'A colossal canvas conquered with patience and precision.',
      howToUnlock: 'Color 500 pixels in a single artwork session.',
      diamondsReward: 100,
      xpReward: 300,
      icon: Icons.workspace_premium_rounded,
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
      shadowColor: Color(0xFFF59E0B),
    ),
    'streak_10': _AchievementMeta(
      id: 'streak_10',
      title: 'In the Zone',
      description: 'Lightning-fast rhythm without a single mistake.',
      howToUnlock: 'Achieve a 10x consecutive combo streak.',
      diamondsReward: 30,
      xpReward: 100,
      icon: Icons.local_fire_department_rounded,
      gradient: [Color(0xFFFF6B6B), Color(0xFFEE5253)],
      shadowColor: Color(0xFFFF6B6B),
    ),
    'streak_25': _AchievementMeta(
      id: 'streak_25',
      title: 'Unstoppable',
      description: 'Pure artistic perfection in rapid succession!',
      howToUnlock: 'Reach an extraordinary 25x combo streak without errors.',
      diamondsReward: 80,
      xpReward: 250,
      icon: Icons.bolt_rounded,
      gradient: [Color(0xFFA855F7), Color(0xFF7C3AED)],
      shadowColor: Color(0xFFA855F7),
    ),
    'eraser_10': _AchievementMeta(
      id: 'eraser_10',
      title: 'Second Thoughts',
      description: 'Great artists refine every detail until it is just right.',
      howToUnlock: 'Use the eraser tool 10 times.',
      diamondsReward: 20,
      xpReward: 50,
      icon: Icons.cleaning_services_rounded,
      gradient: [Color(0xFF06B6D4), Color(0xFF0284C7)],
      shadowColor: Color(0xFF06B6D4),
    ),
  };

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _triggerCelebration() {
    HapticFeedback.mediumImpact();
    _confettiController.forward(from: 0.0);
  }

  String _getRankTitle(int level) {
    if (level <= 2) return 'Novice Artist';
    if (level <= 5) return 'Creative Colorist';
    if (level <= 9) return 'Skilled Painter';
    if (level <= 14) return 'Master Artisan';
    if (level <= 19) return 'Pixel Virtuoso';
    return 'Grandmaster';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<AppSettingsProvider>();
    final gallery = context.watch<GalleryProvider>();
    final storage = context.read<LocalStorageService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final earned = storage
        .getString(ColoringProvider.achievementsStorageKey)
        .split(',')
        .where((e) => e.isNotEmpty)
        .toSet();

    final totalAchievements = ColoringProvider.achievementCatalog.length;
    final earnedCount = earned.length;
    final progressFraction = totalAchievements > 0
        ? (earnedCount / totalAchievements).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppStyle.darkBg : const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(
          l10n.navProfile,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: isDark ? Colors.white : const Color(0xFF1E1E2D),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white70 : const Color(0xFF2D3436),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
        ),
        actions: [
          // Diamond balance & Shop Button
          PressableScale(
            onTap: () {
              HapticFeedback.lightImpact();
              DiamondShopSheet.show(context);
            },
            scale: 0.95,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9F43).withAlpha(40),
                    const Color(0xFFFF5252).withAlpha(30),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD24C).withAlpha(140),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RollingCount(
                    settings.diamondsAvailable,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.diamond_rounded,
                    color: Color(0xFFFFD24C),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD24C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 10,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Settings button (moved from Home Screen)
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF2D3436),
            ),
            tooltip: 'Settings',
            onPressed: () {
              HapticFeedback.lightImpact();
              showSettingsSheet(context);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Hero Level Passport Card
              StaggeredEntrance(
                slot: 0,
                child: _LevelPassportCard(
                  settings: settings,
                  rankTitle: _getRankTitle(settings.playerLevel),
                  onTap: () => _showLevelPerksSheet(context, settings),
                ),
              ),

              const SizedBox(height: 14),

              // Prominent Diamond Shop Action Banner
              StaggeredEntrance(
                slot: 1,
                child: PressableScale(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    DiamondShopSheet.show(context);
                  },
                  scale: 0.98,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF2D184C),
                                const Color(0xFF3F1B4E),
                              ]
                            : [
                                const Color(0xFFFFF3E0),
                                const Color(0xFFFFE0B2),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFF9F43).withAlpha(isDark ? 80 : 120),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9F43).withAlpha(isDark ? 30 : 25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9D2E).withAlpha(120),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.diamond_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diamond Shop',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Get hints, bombs & premium art',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF795548),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9F43), Color(0xFFFF5252)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5252).withAlpha(90),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Shop 💎',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Section Header: Stats
              StaggeredEntrance(
                slot: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF4A4E69),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Career Statistics',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Lifetime Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.65,
                children: [
                  _StatTileData(
                    icon: Icons.palette_rounded,
                    gradient: const [Color(0xFF00B894), Color(0xFF00CEC9)],
                    color: const Color(0xFF00B894),
                    label: 'Artworks done',
                    value: gallery.completedIds.length,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Artworks Completed',
                      value: '${gallery.completedIds.length}',
                      subtitle: 'Masterpieces finished and saved to your collection.',
                      icon: Icons.palette_rounded,
                      color: const Color(0xFF00B894),
                      actionLabel: 'View My Gallery',
                      onAction: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          fadeThroughRoute(const GalleryScreen(), name: 'gallery'),
                        );
                      },
                    ),
                  ),
                  _StatTileData(
                    icon: Icons.grid_4x4_rounded,
                    gradient: const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    color: const Color(0xFF6C5CE7),
                    label: 'Cells colored',
                    value: settings.lifetimeCellsColored,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Cells Colored',
                      value: '${settings.lifetimeCellsColored}',
                      subtitle:
                          'Every single colored pixel brings your artwork to life. Keep tapping to create beauty!',
                      icon: Icons.grid_4x4_rounded,
                      color: const Color(0xFF6C5CE7),
                    ),
                  ),
                  _StatTileData(
                    icon: Icons.local_fire_department_rounded,
                    gradient: const [Color(0xFFFF7675), Color(0xFFD63031)],
                    color: const Color(0xFFFF7675),
                    label: 'Current streak',
                    value: gallery.dailyStreak,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Current Streak',
                      value: '${gallery.dailyStreak} Days',
                      subtitle:
                          'Color at least one artwork each day to maintain your streak and earn diamond bonuses!',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF7675),
                    ),
                  ),
                  _StatTileData(
                    icon: Icons.emoji_events_rounded,
                    gradient: const [Color(0xFFFDCB6E), Color(0xFFE17055)],
                    color: const Color(0xFFFFB300),
                    label: 'Best streak',
                    value: gallery.bestStreak,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Best Daily Streak',
                      value: '${gallery.bestStreak} Days',
                      subtitle:
                          'Your highest historical daily streak. Challenge yourself to set a brand new record!',
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                  _StatTileData(
                    icon: Icons.diamond_rounded,
                    gradient: const [Color(0xFFFF9F43), Color(0xFFFF5252)],
                    color: const Color(0xFFFF9F43),
                    label: 'Diamonds',
                    value: settings.diamondsAvailable,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Diamonds Balance',
                      value: '${settings.diamondsAvailable} 💎',
                      subtitle:
                          'Use diamonds to unlock premium artworks, hints, bombs, and magical paint tools.',
                      icon: Icons.diamond_rounded,
                      color: const Color(0xFFFF9F43),
                      actionLabel: 'Open Diamond Shop',
                      onAction: () {
                        Navigator.of(context).pop();
                        DiamondShopSheet.show(context);
                      },
                    ),
                  ),
                  _StatTileData(
                    icon: Icons.stars_rounded,
                    gradient: const [Color(0xFF8A2BE2), Color(0xFFDA22FF)],
                    color: const Color(0xFF8A2BE2),
                    label: 'Total XP',
                    value: settings.totalXp,
                    onTap: () => _showStatDetailSheet(
                      context,
                      title: 'Lifetime XP',
                      value: '${settings.totalXp} XP',
                      subtitle:
                          'Earn XP by coloring cells, completing artworks, and keeping up daily streaks.',
                      icon: Icons.stars_rounded,
                      color: const Color(0xFF8A2BE2),
                    ),
                  ),
                ].indexed.map((entry) {
                  final (i, data) = entry;
                  return StaggeredEntrance(
                    slot: 2 + i,
                    child: _ModernStatTile(data: data),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Section Header: Achievements + Progress Bar
              StaggeredEntrance(
                slot: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.military_tech_rounded,
                          size: 22,
                          color: isDark ? Colors.white70 : const Color(0xFF4A4E69),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Achievements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppStyle.primary.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppStyle.primary.withAlpha(isDark ? 80 : 50),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppStyle.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$earnedCount / $totalAchievements',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyle.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: progressFraction),
                        duration: const Duration(milliseconds: 700),
                        curve: Motion.standard,
                        builder: (context, val, _) => LinearProgressIndicator(
                          value: val,
                          minHeight: 6,
                          backgroundColor:
                              isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(
                            earnedCount == totalAchievements
                                ? const Color(0xFF10B981)
                                : AppStyle.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Achievement Badges Grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: ColoringProvider.achievementCatalog.entries
                    .toList()
                    .indexed
                    .map((entry) {
                  final (i, e) = entry;
                  final isEarned = earned.contains(e.key);
                  final meta = _achievementsData[e.key] ??
                      _AchievementMeta(
                        id: e.key,
                        title: e.value,
                        description: 'Special milestone for dedicated artists.',
                        howToUnlock: 'Keep coloring to unlock.',
                        diamondsReward: 25,
                        xpReward: 75,
                        icon: Icons.emoji_events_rounded,
                        gradient: [const Color(0xFFFFD24C), const Color(0xFFFF9D2E)],
                        shadowColor: const Color(0xFFFF9D2E),
                      );

                  return StaggeredEntrance(
                    slot: 9 + i,
                    child: _AchievementBadgeTile(
                      meta: meta,
                      earned: isEarned,
                      onTap: () => _showAchievementDetailSheet(
                        context,
                        meta: meta,
                        earned: isEarned,
                        onCelebrate: isEarned ? _triggerCelebration : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Fullscreen celebratory confetti overlay
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiOverlay(animation: _confettiController),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the Level Perks modal bottom sheet.
  void _showLevelPerksSheet(BuildContext context, AppSettingsProvider settings) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        const nextRewardDiamonds = 50;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 100 : 30),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9D2E).withAlpha(120),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${settings.playerLevel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Level ${settings.playerLevel} • ${_getRankTitle(settings.playerLevel)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${settings.xpToNextLevel} XP needed to reach Level ${settings.playerLevel + 1}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              // Next Level Reward Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyle.primary.withAlpha(isDark ? 40 : 15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppStyle.primary.withAlpha(isDark ? 80 : 35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9D2E).withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFFFF9D2E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Level Reward',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+$nextRewardDiamonds Diamonds Bonus 💎',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Keep Coloring',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Displays contextual information when a stat card is tapped.
  void _showStatDetailSheet(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 100 : 30),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(60), width: 2),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onAction,
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Got It',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Displays detailed achievement dialog with celebration actions.
  void _showAchievementDetailSheet(
    BuildContext context, {
    required _AchievementMeta meta,
    required bool earned,
    VoidCallback? onCelebrate,
  }) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 100 : 30),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Big Icon with Glow / Lock Disc
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: earned
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: meta.gradient,
                        )
                      : null,
                  color: earned
                      ? null
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  boxShadow: earned
                      ? [
                          BoxShadow(
                            color: meta.shadowColor.withAlpha(120),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    earned ? meta.icon : Icons.lock_outline_rounded,
                    size: 38,
                    color: earned
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: earned
                      ? const Color(0xFF10B981).withAlpha(25)
                      : (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: earned
                        ? const Color(0xFF10B981).withAlpha(80)
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
                child: Text(
                  earned ? '🎉 UNLOCKED' : '🔒 LOCKED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: earned
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                meta.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              // Requirement & Reward Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 16,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meta.howToUnlock,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, thickness: 0.8),
                    Row(
                      children: [
                        const Icon(
                          Icons.card_giftcard_rounded,
                          size: 16,
                          color: Color(0xFFFF9D2E),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reward: +${meta.diamondsReward} Diamonds 💎  •  +${meta.xpReward} XP',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF9D2E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (earned) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta.gradient.first,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                      shadowColor: meta.shadowColor.withAlpha(100),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onCelebrate?.call();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.celebration_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Celebrate Achievement!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyle.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Got It, Let\'s Paint!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Dynamic Cosmic Level Passport Card
class _LevelPassportCard extends StatelessWidget {
  final AppSettingsProvider settings;
  final String rankTitle;
  final VoidCallback onTap;

  const _LevelPassportCard({
    required this.settings,
    required this.rankTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = settings.xpProgressInLevel;
    final percent = (progress * 100).toInt();

    return PressableScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withAlpha(isDark ? 90 : 70),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // Cosmic Background Gradient
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5B1BB8),
                      Color(0xFF8A2BE2),
                      Color(0xFFB14CFF),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Avatar Badge + Title & Rank
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Dual-Ring Illuminated Level Avatar
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withAlpha(80),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF9D2E).withAlpha(120),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFE066),
                                    Color(0xFFFF9D2E),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${settings.playerLevel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFD700),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Color(0xFF6B21A8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Level ${settings.playerLevel}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Rank Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(60),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 13,
                                      color: Color(0xFFFFE066),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rankTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // XP Status Line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${settings.xpToNextLevel} XP to Level ${settings.playerLevel + 1}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Color(0xFFFFE066),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Glossy XP Progress Bar
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Motion.standard,
                          builder: (context, v, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: v.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFE066),
                                    Color(0xFFFF9D2E),
                                    Color(0xFFFF5252),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Ambient background decorative glow circles
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(25),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: 100,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF9D2E).withAlpha(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTileData {
  final IconData icon;
  final List<Color> gradient;
  final Color color;
  final String label;
  final int value;
  final VoidCallback onTap;

  const _StatTileData({
    required this.icon,
    required this.gradient,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });
}

/// Upgraded Stat Tile: Soft glow backlight, squircle gradient icon, press-scale animation.
class _ModernStatTile extends StatelessWidget {
  final _StatTileData data;

  const _ModernStatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: data.onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: data.color.withAlpha(isDark ? 60 : 35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withAlpha(isDark ? 30 : 18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Squircle Gradient Icon Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: data.gradient,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: data.color.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(data.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RollingCount(
                    data.value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E2D),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upgraded Achievement Badge Tile:
/// Unique vibrant gradients, 3D pill aesthetics, unlocked indicator badge, and tap inspector.
class _AchievementBadgeTile extends StatelessWidget {
  final _AchievementMeta meta;
  final bool earned;
  final VoidCallback onTap;

  const _AchievementBadgeTile({
    required this.meta,
    required this.earned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: earned
              ? (isDark
                  ? meta.shadowColor.withAlpha(20)
                  : Colors.white)
              : (isDark ? Colors.white.withAlpha(6) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: earned
                ? meta.shadowColor.withAlpha(isDark ? 80 : 50)
                : (isDark ? Colors.white10 : Colors.black.withAlpha(12)),
            width: earned ? 1.4 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: meta.shadowColor.withAlpha(isDark ? 40 : 25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge Circle
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: earned
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: meta.gradient,
                          )
                        : null,
                    color: earned
                        ? null
                        : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                    boxShadow: earned
                        ? [
                            BoxShadow(
                              color: meta.shadowColor.withAlpha(110),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    earned ? meta.icon : Icons.lock_rounded,
                    color: earned
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.black38),
                    size: 26,
                  ),
                ),
                if (earned)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              meta.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: earned ? FontWeight.w700 : FontWeight.w600,
                color: earned
                    ? (isDark ? Colors.white : const Color(0xFF1E1E2D))
                    : (isDark ? Colors.white38 : Colors.black45),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              earned ? 'Unlocked' : 'Locked',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: earned
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white30 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
