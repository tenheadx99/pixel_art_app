import 'package:flutter/material.dart';

/// Predefined metric types that the client app evaluates.
enum AchievementMetricType {
  completedArts('completed_arts', 'Completed Artworks', 'Total artworks finished 100%'),
  dailyStreak('daily_streak', 'Daily Challenge Streak', 'Consecutive days of completing daily art'),
  singleSessionFills('single_session_fills', 'Pixels in One Artwork', 'Pixels filled in a single painting session'),
  comboStreak('combo_streak', 'Combo Streak', 'Consecutive correct pixels without any mistake'),
  erasersUsed('erasers_used', 'Erasers Used', 'Total times the eraser tool was used'),
  bombsUsed('bombs_used', 'Bombs Used', 'Total color bombs detonated'),
  wandsUsed('wands_used', 'Magic Wands Used', 'Total magic wands cast'),
  customArtsCreated('custom_arts_created', 'Custom Artworks Created', 'Arts created via Draw Canvas or Camera import'),
  playerLevel('player_level', 'Player Level', 'Account experience level reached');

  final String id;
  final String label;
  final String description;

  const AchievementMetricType(this.id, this.label, this.description);

  static AchievementMetricType fromId(String id) {
    return AchievementMetricType.values.firstWhere(
      (m) => m.id == id,
      orElse: () => AchievementMetricType.completedArts,
    );
  }
}

/// Category grouping for achievements.
enum AchievementCategory {
  milestones('milestones', 'Milestones', Icons.emoji_events_rounded),
  streaks('streaks', 'Streaks & Daily', Icons.local_fire_department_rounded),
  powerups('powerups', 'Boosters', Icons.bolt_rounded),
  creator('creator', 'Studio & Custom', Icons.brush_rounded),
  mastery('mastery', 'Mastery', Icons.workspace_premium_rounded);

  final String id;
  final String label;
  final IconData icon;

  const AchievementCategory(this.id, this.label, this.icon);

  static AchievementCategory fromId(String id) {
    return AchievementCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => AchievementCategory.milestones,
    );
  }
}

/// An individual achievement configuration item.
class AchievementItem {
  final String id;
  final String title;
  final String description;
  final String howToUnlock;
  final String metricType;
  final int targetValue;
  final int diamondsReward;
  final int xpReward;
  final String iconName;
  final String colorHex;
  final String category;
  final bool isEnabled;
  final int order;

  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.howToUnlock,
    required this.metricType,
    required this.targetValue,
    this.diamondsReward = 50,
    this.xpReward = 100,
    this.iconName = 'auto_awesome',
    this.colorHex = 'FFFF9F43',
    this.category = 'milestones',
    this.isEnabled = true,
    this.order = 0,
  });

  AchievementMetricType get metric => AchievementMetricType.fromId(metricType);
  AchievementCategory get cat => AchievementCategory.fromId(category);

  Color get color {
    final hex = colorHex.replaceAll('#', '').trim();
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFFFF9F43);
  }

  IconData get iconData {
    switch (iconName) {
      case 'brush':
        return Icons.brush_rounded;
      case 'palette':
        return Icons.palette_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'today':
      case 'calendar_month':
        return Icons.calendar_month_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'camera_alt':
        return Icons.camera_alt_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'auto_awesome':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  factory AchievementItem.fromMap(Map<dynamic, dynamic> map) {
    return AchievementItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      howToUnlock: map['howToUnlock'] as String? ?? map['how_to_unlock'] as String? ?? '',
      metricType: map['metricType'] as String? ?? map['metric_type'] as String? ?? 'completed_arts',
      targetValue: (map['targetValue'] ?? map['target_value'] as num?)?.toInt() ?? 1,
      diamondsReward: (map['diamondsReward'] ?? map['diamonds_reward'] as num?)?.toInt() ?? 50,
      xpReward: (map['xpReward'] ?? map['xp_reward'] as num?)?.toInt() ?? 100,
      iconName: map['iconName'] as String? ?? map['icon_name'] as String? ?? 'auto_awesome',
      colorHex: map['colorHex'] as String? ?? map['color_hex'] as String? ?? 'FFFF9F43',
      category: map['category'] as String? ?? 'milestones',
      isEnabled: map['isEnabled'] as bool? ?? map['is_enabled'] as bool? ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'howToUnlock': howToUnlock,
      'metricType': metricType,
      'targetValue': targetValue,
      'diamondsReward': diamondsReward,
      'xpReward': xpReward,
      'iconName': iconName,
      'colorHex': colorHex,
      'category': category,
      'isEnabled': isEnabled,
      'order': order,
    };
  }

  AchievementItem copyWith({
    String? id,
    String? title,
    String? description,
    String? howToUnlock,
    String? metricType,
    int? targetValue,
    int? diamondsReward,
    int? xpReward,
    String? iconName,
    String? colorHex,
    String? category,
    bool? isEnabled,
    int? order,
  }) {
    return AchievementItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      howToUnlock: howToUnlock ?? this.howToUnlock,
      metricType: metricType ?? this.metricType,
      targetValue: targetValue ?? this.targetValue,
      diamondsReward: diamondsReward ?? this.diamondsReward,
      xpReward: xpReward ?? this.xpReward,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
    );
  }
}

/// Overall Achievements configuration container.
class AchievementsConfig {
  final bool isEnabled;
  final List<AchievementItem> achievements;

  const AchievementsConfig({
    this.isEnabled = true,
    this.achievements = const [],
  });

  factory AchievementsConfig.fromMap(Map<dynamic, dynamic> map) {
    final rawList = map['achievements'] as List? ?? [];
    final items = rawList
        .whereType<Map>()
        .map((m) => AchievementItem.fromMap(m))
        .toList();

    return AchievementsConfig(
      isEnabled: map['isEnabled'] as bool? ?? map['is_enabled'] as bool? ?? true,
      achievements: items.isNotEmpty ? items : defaultAchievements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'achievements': achievements.map((a) => a.toMap()).toList(),
    };
  }

  /// Default baseline achievements (including all historical achievements to guarantee zero regression).
  static const List<AchievementItem> defaultAchievements = [
    AchievementItem(
      id: 'complete_first',
      title: 'First Masterpiece',
      description: 'Your artistic journey has begun with flying colors!',
      howToUnlock: 'Complete your very first pixel artwork.',
      metricType: 'completed_arts',
      targetValue: 1,
      diamondsReward: 50,
      xpReward: 100,
      iconName: 'auto_awesome',
      colorHex: 'FFFF9F43',
      category: 'milestones',
      isEnabled: true,
      order: 1,
    ),
    AchievementItem(
      id: 'fill_10',
      title: 'Getting Started',
      description: 'First steps on the canvas — feeling the flow.',
      howToUnlock: 'Color 10 pixels in a single painting session.',
      metricType: 'single_session_fills',
      targetValue: 10,
      diamondsReward: 20,
      xpReward: 50,
      iconName: 'brush',
      colorHex: 'FF10B981',
      category: 'milestones',
      isEnabled: true,
      order: 2,
    ),
    AchievementItem(
      id: 'fill_100',
      title: 'Dedicated Artist',
      description: 'Hours of focus turning empty squares into vibrant art.',
      howToUnlock: 'Color 100 pixels in a single artwork.',
      metricType: 'single_session_fills',
      targetValue: 100,
      diamondsReward: 50,
      xpReward: 150,
      iconName: 'palette',
      colorHex: 'FF6366F1',
      category: 'milestones',
      isEnabled: true,
      order: 3,
    ),
    AchievementItem(
      id: 'fill_500',
      title: 'Pixel Master',
      description: 'A colossal canvas conquered with patience and precision.',
      howToUnlock: 'Color 500 pixels in a single artwork session.',
      metricType: 'single_session_fills',
      targetValue: 500,
      diamondsReward: 100,
      xpReward: 300,
      iconName: 'workspace_premium',
      colorHex: 'FFF59E0B',
      category: 'milestones',
      isEnabled: true,
      order: 4,
    ),
    AchievementItem(
      id: 'streak_10',
      title: 'In the Zone',
      description: 'Lightning-fast rhythm without a single mistake.',
      howToUnlock: 'Achieve a 10x consecutive combo streak.',
      metricType: 'combo_streak',
      targetValue: 10,
      diamondsReward: 30,
      xpReward: 100,
      iconName: 'local_fire_department',
      colorHex: 'FFFF6B6B',
      category: 'streaks',
      isEnabled: true,
      order: 5,
    ),
    AchievementItem(
      id: 'streak_25',
      title: 'Unstoppable',
      description: 'Pure artistic perfection in rapid succession!',
      howToUnlock: 'Reach an extraordinary 25x combo streak without errors.',
      metricType: 'combo_streak',
      targetValue: 25,
      diamondsReward: 80,
      xpReward: 250,
      iconName: 'bolt',
      colorHex: 'FFA855F7',
      category: 'streaks',
      isEnabled: true,
      order: 6,
    ),
    AchievementItem(
      id: 'eraser_10',
      title: 'Second Thoughts',
      description: 'Great artists refine every detail until it is just right.',
      howToUnlock: 'Use the eraser tool 10 times.',
      metricType: 'erasers_used',
      targetValue: 10,
      diamondsReward: 20,
      xpReward: 50,
      iconName: 'cleaning_services',
      colorHex: 'FF06B6D4',
      category: 'powerups',
      isEnabled: true,
      order: 7,
    ),
    // High-retention new additions:
    AchievementItem(
      id: 'daily_streak_3',
      title: 'Three\'s a Charm',
      description: 'Consistency is where true artistry begins.',
      howToUnlock: 'Complete the Daily Challenge 3 days in a row.',
      metricType: 'daily_streak',
      targetValue: 3,
      diamondsReward: 40,
      xpReward: 120,
      iconName: 'today',
      colorHex: 'FFF59E0B',
      category: 'streaks',
      isEnabled: true,
      order: 8,
    ),
    AchievementItem(
      id: 'daily_streak_7',
      title: 'Weekly Champion',
      description: 'A full week of artistic dedication. Magnificent!',
      howToUnlock: 'Maintain a 7-day daily challenge streak.',
      metricType: 'daily_streak',
      targetValue: 7,
      diamondsReward: 100,
      xpReward: 350,
      iconName: 'emoji_events',
      colorHex: 'FF10B981',
      category: 'streaks',
      isEnabled: true,
      order: 9,
    ),
    AchievementItem(
      id: 'complete_5_arts',
      title: 'Art Collector',
      description: 'Your private gallery is growing into an exhibition.',
      howToUnlock: 'Complete 5 full artworks in your gallery.',
      metricType: 'completed_arts',
      targetValue: 5,
      diamondsReward: 60,
      xpReward: 200,
      iconName: 'palette',
      colorHex: 'FF8B5CF6',
      category: 'milestones',
      isEnabled: true,
      order: 10,
    ),
    AchievementItem(
      id: 'complete_25_arts',
      title: 'Gallery Virtuoso',
      description: 'A legendary master of colors and imagination.',
      howToUnlock: 'Complete 25 artworks across any category.',
      metricType: 'completed_arts',
      targetValue: 25,
      diamondsReward: 250,
      xpReward: 1000,
      iconName: 'military_tech',
      colorHex: 'FFEAB308',
      category: 'milestones',
      isEnabled: true,
      order: 11,
    ),
    AchievementItem(
      id: 'use_bombs_10',
      title: 'Kaboom Specialist',
      description: 'Explosions of color across vast canvas spaces!',
      howToUnlock: 'Detonate 10 Color Bombs during your sessions.',
      metricType: 'bombs_used',
      targetValue: 10,
      diamondsReward: 35,
      xpReward: 100,
      iconName: 'bolt',
      colorHex: 'FFEF4444',
      category: 'powerups',
      isEnabled: true,
      order: 12,
    ),
    AchievementItem(
      id: 'use_wands_10',
      title: 'Magic Hands',
      description: 'Finding that elusive hidden pixel like a wizard.',
      howToUnlock: 'Use Magic Wands 10 times to locate stubborn numbers.',
      metricType: 'wands_used',
      targetValue: 10,
      diamondsReward: 35,
      xpReward: 100,
      iconName: 'auto_awesome',
      colorHex: 'FF3B82F6',
      category: 'powerups',
      isEnabled: true,
      order: 13,
    ),
    AchievementItem(
      id: 'create_custom_art',
      title: 'Studio Creator',
      description: 'Brought your own imagination to life on the canvas.',
      howToUnlock: 'Create a custom artwork using Draw Canvas or Camera import.',
      metricType: 'custom_arts_created',
      targetValue: 1,
      diamondsReward: 50,
      xpReward: 150,
      iconName: 'camera_alt',
      colorHex: 'FFEC4899',
      category: 'creator',
      isEnabled: true,
      order: 14,
    ),
    AchievementItem(
      id: 'reach_level_5',
      title: 'Rising Star',
      description: 'Level 5 reached! The coloring world recognizes your talent.',
      howToUnlock: 'Earn enough XP to reach Player Level 5.',
      metricType: 'player_level',
      targetValue: 5,
      diamondsReward: 50,
      xpReward: 150,
      iconName: 'star',
      colorHex: 'FFF59E0B',
      category: 'mastery',
      isEnabled: true,
      order: 15,
    ),
  ];
}

