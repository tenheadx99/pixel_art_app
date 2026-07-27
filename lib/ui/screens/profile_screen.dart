import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/coloring_provider.dart';
import '../../data/services/local_storage_service.dart';
import '../theme/app_style.dart';

import '../../l10n/app_localizations.dart';

/// Player profile / stats: level + XP, lifetime stats, and the achievements
/// grid (earned vs. still-locked).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Map<String, IconData> _achievementIcons = {
    'complete_first': Icons.auto_awesome_rounded,
    'fill_10': Icons.brush_rounded,
    'fill_100': Icons.palette_rounded,
    'fill_500': Icons.workspace_premium_rounded,
    'streak_10': Icons.local_fire_department_rounded,
    'streak_25': Icons.bolt_rounded,
    'eraser_10': Icons.cleaning_services_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<AppSettingsProvider>();
    final gallery = context.watch<GalleryProvider>();
    final storage = context.read<LocalStorageService>();
    final earned = storage
        .getString(ColoringProvider.achievementsStorageKey)
        .split(',')
        .where((e) => e.isNotEmpty)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navProfile),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _LevelCard(settings: settings),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _StatTile(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF00B894),
                label: 'Artworks done',
                value: '${gallery.completedIds.length}',
              ),
              _StatTile(
                icon: Icons.grid_on_rounded,
                color: const Color(0xFF6C5CE7),
                label: 'Cells colored',
                value: '${settings.lifetimeCellsColored}',
              ),
              _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFF7043),
                label: 'Current streak',
                value: '${gallery.dailyStreak}',
              ),
              _StatTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFFFB300),
                label: 'Best streak',
                value: '${gallery.bestStreak}',
              ),
              _StatTile(
                icon: Icons.diamond_rounded,
                color: const Color(0xFFFF9D2E),
                label: 'Diamonds',
                value: '${settings.diamondsAvailable}',
              ),
              _StatTile(
                icon: Icons.star_rounded,
                color: const Color(0xFF8A2BE2),
                label: 'Total XP',
                value: '${settings.totalXp}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Achievements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${earned.length}/${ColoringProvider.achievementCatalog.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppStyle.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: ColoringProvider.achievementCatalog.entries.map((e) {
              return _AchievementBadge(
                icon: _achievementIcons[e.key] ?? Icons.emoji_events_rounded,
                name: e.value,
                earned: earned.contains(e.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final AppSettingsProvider settings;
  const _LevelCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A2BE2), Color(0xFFB14CFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppStyle.primary.withAlpha(isDark ? 80 : 60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                  ),
                ),
                child: Text(
                  '${settings.playerLevel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${settings.playerLevel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${settings.xpToNextLevel} XP to level ${settings.playerLevel + 1}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: settings.xpProgressInLevel,
              minHeight: 10,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD24C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(14) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 0 : 12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(40),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool earned;

  const _AchievementBadge({
    required this.icon,
    required this.name,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white60 : Colors.black38;
    return Opacity(
      opacity: earned ? 1 : 0.45,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: earned
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                    )
                  : null,
              color: earned ? null : base.withAlpha(40),
              boxShadow: earned
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF9D2E).withAlpha(120),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              earned ? icon : Icons.lock_rounded,
              color: earned ? Colors.white : base,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
