import 'dart:ui';
import 'package:flutter/material.dart';

/// Configuration for Growth & Engagement features on the Home Screen:
/// - Top Hero Carousel / Event Banner
/// - Daily Spotlight Artwork Recommendation
/// - Mystery Diamond Gift Box
///
/// Loaded from Firestore root doc `pixel_art/{flavor}` under `homeEngagement`.
class HomeEngagementConfig {
  final bool heroBannerEnabled;
  final String heroBannerTitle;
  final String heroBannerSubtitle;
  final String heroBannerBadge;
  final String heroBannerGradient; // 'sunset', 'ocean', 'cyber', 'aurora'
  final String heroBannerTargetType; // 'category', 'shelf', 'artwork', 'shop'
  final String? heroBannerTargetId;

  final bool dailySpotlightEnabled;
  final String? dailySpotlightArtId;
  final String dailySpotlightTitle;

  final bool mysteryGiftBoxEnabled;
  final int mysteryGiftDiamonds;

  const HomeEngagementConfig({
    this.heroBannerEnabled = false,
    this.heroBannerTitle = 'Weekend Pixel Festival',
    this.heroBannerSubtitle = 'Exclusive new artworks & double XP active!',
    this.heroBannerBadge = 'FEATURED',
    this.heroBannerGradient = 'sunset',
    this.heroBannerTargetType = 'category',
    this.heroBannerTargetId,
    this.dailySpotlightEnabled = false,
    this.dailySpotlightArtId,
    this.dailySpotlightTitle = 'Artist of the Day Pick',
    this.mysteryGiftBoxEnabled = false,
    this.mysteryGiftDiamonds = 20,
  });

  HomeEngagementConfig copyWith({
    bool? heroBannerEnabled,
    String? heroBannerTitle,
    String? heroBannerSubtitle,
    String? heroBannerBadge,
    String? heroBannerGradient,
    String? heroBannerTargetType,
    String? heroBannerTargetId,
    bool? dailySpotlightEnabled,
    String? dailySpotlightArtId,
    String? dailySpotlightTitle,
    bool? mysteryGiftBoxEnabled,
    int? mysteryGiftDiamonds,
  }) {
    return HomeEngagementConfig(
      heroBannerEnabled: heroBannerEnabled ?? this.heroBannerEnabled,
      heroBannerTitle: heroBannerTitle ?? this.heroBannerTitle,
      heroBannerSubtitle: heroBannerSubtitle ?? this.heroBannerSubtitle,
      heroBannerBadge: heroBannerBadge ?? this.heroBannerBadge,
      heroBannerGradient: heroBannerGradient ?? this.heroBannerGradient,
      heroBannerTargetType: heroBannerTargetType ?? this.heroBannerTargetType,
      heroBannerTargetId: heroBannerTargetId ?? this.heroBannerTargetId,
      dailySpotlightEnabled:
          dailySpotlightEnabled ?? this.dailySpotlightEnabled,
      dailySpotlightArtId: dailySpotlightArtId ?? this.dailySpotlightArtId,
      dailySpotlightTitle: dailySpotlightTitle ?? this.dailySpotlightTitle,
      mysteryGiftBoxEnabled:
          mysteryGiftBoxEnabled ?? this.mysteryGiftBoxEnabled,
      mysteryGiftDiamonds: mysteryGiftDiamonds ?? this.mysteryGiftDiamonds,
    );
  }

  factory HomeEngagementConfig.fromJson(Map<String, dynamic> json) {
    return HomeEngagementConfig(
      heroBannerEnabled: json['heroBannerEnabled'] as bool? ?? false,
      heroBannerTitle: json['heroBannerTitle'] as String? ??
          'Weekend Pixel Festival',
      heroBannerSubtitle: json['heroBannerSubtitle'] as String? ??
          'Exclusive new artworks & double XP active!',
      heroBannerBadge: json['heroBannerBadge'] as String? ?? 'FEATURED',
      heroBannerGradient: json['heroBannerGradient'] as String? ?? 'sunset',
      heroBannerTargetType:
          json['heroBannerTargetType'] as String? ?? 'category',
      heroBannerTargetId: json['heroBannerTargetId'] as String?,
      dailySpotlightEnabled: json['dailySpotlightEnabled'] as bool? ?? false,
      dailySpotlightArtId: json['dailySpotlightArtId'] as String?,
      dailySpotlightTitle: json['dailySpotlightTitle'] as String? ??
          'Artist of the Day Pick',
      mysteryGiftBoxEnabled: json['mysteryGiftBoxEnabled'] as bool? ?? false,
      mysteryGiftDiamonds:
          (json['mysteryGiftDiamonds'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
        'heroBannerEnabled': heroBannerEnabled,
        'heroBannerTitle': heroBannerTitle,
        'heroBannerSubtitle': heroBannerSubtitle,
        'heroBannerBadge': heroBannerBadge,
        'heroBannerGradient': heroBannerGradient,
        'heroBannerTargetType': heroBannerTargetType,
        if (heroBannerTargetId != null)
          'heroBannerTargetId': heroBannerTargetId,
        'dailySpotlightEnabled': dailySpotlightEnabled,
        if (dailySpotlightArtId != null)
          'dailySpotlightArtId': dailySpotlightArtId,
        'dailySpotlightTitle': dailySpotlightTitle,
        'mysteryGiftBoxEnabled': mysteryGiftBoxEnabled,
        'mysteryGiftDiamonds': mysteryGiftDiamonds,
      };

  List<Color> get gradientColors {
    switch (heroBannerGradient.toLowerCase()) {
      case 'ocean':
        return const [Color(0xFF0077B6), Color(0xFF00B4D8)];
      case 'cyber':
        return const [Color(0xFF7209B7), Color(0xFF4CC9F0)];
      case 'aurora':
        return const [Color(0xFF06D6A0), Color(0xFF118AB2)];
      case 'sunset':
      default:
        return const [Color(0xFFFF5964), Color(0xFFFA9500)];
    }
  }
}

