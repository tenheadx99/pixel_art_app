import 'package:flutter/material.dart';

/// Supported social and web platforms with default metadata.
enum SocialPlatform {
  instagram('instagram', 'Instagram', Icons.camera_alt_rounded, Color(0xFFE1306C)),
  facebook('facebook', 'Facebook', Icons.facebook, Color(0xFF1877F2)),
  youtube('youtube', 'YouTube', Icons.smart_display_rounded, Color(0xFFFF0000)),
  discord('discord', 'Discord', Icons.discord, Color(0xFF5865F2)),
  x('x', 'X (Twitter)', Icons.alternate_email_rounded, Color(0xFF1DA1F2)),
  tiktok('tiktok', 'TikTok', Icons.tiktok, Color(0xFFFE2C55)),
  telegram('telegram', 'Telegram', Icons.telegram, Color(0xFF229ED9)),
  reddit('reddit', 'Reddit', Icons.reddit, Color(0xFFFF4500)),
  pinterest('pinterest', 'Pinterest', Icons.push_pin_rounded, Color(0xFFE60023)),
  threads('threads', 'Threads', Icons.alternate_email_rounded, Color(0xFF111111)),
  website('website', 'Website', Icons.language_rounded, Color(0xFF00A8FF)),
  custom('custom', 'Custom Link', Icons.link_rounded, Color(0xFF706FD3));

  final String id;
  final String displayName;
  final IconData defaultIcon;
  final Color defaultColor;

  const SocialPlatform(this.id, this.displayName, this.defaultIcon, this.defaultColor);

  static SocialPlatform fromString(String? key) {
    if (key == null) return SocialPlatform.custom;
    final normalized = key.trim().toLowerCase();
    for (final p in SocialPlatform.values) {
      if (p.id == normalized) return p;
    }
    if (normalized == 'twitter') return SocialPlatform.x;
    if (normalized == 'web' || normalized == 'globe') return SocialPlatform.website;
    return SocialPlatform.custom;
  }
}

/// A single dynamic social or web page entry configured by the admin.
class SocialLink {
  final String id;
  final String platform;
  final String title;
  final String? subtitle;
  final String url;
  final String? iconKey;
  final String? colorHex;
  final bool isEnabled;
  final int order;
  final String openMode;

  const SocialLink({
    required this.id,
    required this.platform,
    required this.title,
    this.subtitle,
    required this.url,
    this.iconKey,
    this.colorHex,
    this.isEnabled = true,
    this.order = 0,
    this.openMode = 'external',
  });

  SocialPlatform get platformEnum => SocialPlatform.fromString(platform);

  bool get isInstagram => platformEnum == SocialPlatform.instagram;

  /// Resolves the icon based on iconKey or platform preset.
  IconData get resolvedIcon {
    final key = (iconKey ?? platform).toLowerCase().trim();
    switch (key) {
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'facebook':
        return Icons.facebook;
      case 'youtube':
        return Icons.smart_display_rounded;
      case 'discord':
        return Icons.discord;
      case 'x':
      case 'twitter':
        return Icons.alternate_email_rounded;
      case 'tiktok':
        return Icons.tiktok;
      case 'telegram':
        return Icons.telegram;
      case 'reddit':
        return Icons.reddit;
      case 'snapchat':
        return Icons.snapchat;
      case 'pinterest':
        return Icons.push_pin_rounded;
      case 'threads':
        return Icons.alternate_email_rounded;
      case 'website':
      case 'web':
      case 'globe':
        return Icons.language_rounded;
      case 'email':
      case 'mail':
        return Icons.email_outlined;
      case 'support':
        return Icons.support_agent_rounded;
      case 'community':
      case 'group':
        return Icons.groups_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'sparkles':
        return Icons.auto_awesome_rounded;
      default:
        return platformEnum.defaultIcon;
    }
  }

  /// Resolves the brand or custom tint color.
  Color get resolvedColor {
    if (colorHex != null && colorHex!.trim().isNotEmpty) {
      final hex = colorHex!.trim().replaceAll('#', '');
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) return Color(val);
      } else if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) return Color(val);
      }
    }
    return platformEnum.defaultColor;
  }

  factory SocialLink.fromMap(Map<String, dynamic> map, {String? defaultId}) {
    int parsedOrder = 0;
    final o = map['order'];
    if (o is num) {
      parsedOrder = o.toInt();
    } else if (o is String) {
      parsedOrder = int.tryParse(o) ?? 0;
    }

    bool parsedEnabled = true;
    final en = map['isEnabled'] ?? map['enabled'] ?? map['active'];
    if (en is bool) {
      parsedEnabled = en;
    } else if (en is String) {
      parsedEnabled = en.toLowerCase() != 'false';
    }

    return SocialLink(
      id: (map['id'] as String?) ?? defaultId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      platform: (map['platform'] as String?)?.trim() ?? 'custom',
      title: (map['title'] as String?)?.trim() ?? '',
      subtitle: (map['subtitle'] as String?)?.trim(),
      url: (map['url'] as String?)?.trim() ?? '',
      iconKey: (map['iconKey'] as String?)?.trim(),
      colorHex: (map['colorHex'] as String?)?.trim(),
      isEnabled: parsedEnabled,
      order: parsedOrder,
      openMode: (map['openMode'] as String?)?.trim() ?? 'external',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform': platform,
      'title': title,
      if (subtitle != null && subtitle!.isNotEmpty) 'subtitle': subtitle,
      'url': url,
      if (iconKey != null && iconKey!.isNotEmpty) 'iconKey': iconKey,
      if (colorHex != null && colorHex!.isNotEmpty) 'colorHex': colorHex,
      'isEnabled': isEnabled,
      'order': order,
      'openMode': openMode,
    };
  }

  SocialLink copyWith({
    String? id,
    String? platform,
    String? title,
    String? subtitle,
    String? url,
    String? iconKey,
    String? colorHex,
    bool? isEnabled,
    int? order,
    String? openMode,
  }) {
    return SocialLink(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      url: url ?? this.url,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
      openMode: openMode ?? this.openMode,
    );
  }
}

/// The complete social links configuration document for a flavor.
class SocialLinksConfig {
  final bool isEnabled;
  final String sectionTitle;
  final List<SocialLink> links;

  const SocialLinksConfig({
    this.isEnabled = true,
    this.sectionTitle = 'COMMUNITY & SOCIAL',
    this.links = const [],
  });

  factory SocialLinksConfig.fromMap(Map<String, dynamic> map) {
    bool enabled = true;
    final en = map['isEnabled'] ?? map['enabled'];
    if (en is bool) {
      enabled = en;
    } else if (en is String) {
      enabled = en.toLowerCase() != 'false';
    }

    final rawTitle = (map['sectionTitle'] as String?)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : 'COMMUNITY & SOCIAL';

    final rawLinks = map['links'];
    final List<SocialLink> parsedLinks = [];
    if (rawLinks is List) {
      for (int i = 0; i < rawLinks.length; i++) {
        final item = rawLinks[i];
        if (item is Map<String, dynamic>) {
          parsedLinks.add(SocialLink.fromMap(item, defaultId: 'link_$i'));
        } else if (item is Map) {
          parsedLinks.add(
            SocialLink.fromMap(Map<String, dynamic>.from(item), defaultId: 'link_$i'),
          );
        }
      }
    }

    return SocialLinksConfig(
      isEnabled: enabled,
      sectionTitle: title,
      links: parsedLinks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'sectionTitle': sectionTitle,
      'links': links.map((l) => l.toMap()).toList(),
    };
  }

  SocialLinksConfig copyWith({
    bool? isEnabled,
    String? sectionTitle,
    List<SocialLink>? links,
  }) {
    return SocialLinksConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      links: links ?? this.links,
    );
  }
}
