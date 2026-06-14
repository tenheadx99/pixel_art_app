import 'package:flutter/material.dart';

/// Build flavors of the app. Selected at build time via
/// `--dart-define=FLAVOR=<name>` (defaults to [AppFlavor.original]).
enum AppFlavor { original, devotional, anime, pixelcalm }

/// Resolved once from the compile-time environment.
const String _flavorName = String.fromEnvironment(
  'FLAVOR',
  defaultValue: 'original',
);

AppFlavor get currentFlavor {
  switch (_flavorName) {
    case 'devotional':
      return AppFlavor.devotional;
    case 'anime':
      return AppFlavor.anime;
    case 'pixelcalm':
      return AppFlavor.pixelcalm;
    case 'original':
    default:
      return AppFlavor.original;
  }
}

/// Per-flavor branding, theming, monetization and content routing. Keep all
/// flavor-specific values here so the rest of the app reads from
/// [FlavorConfig.current] rather than hardcoding. Adding a new audience is one
/// entry in [_configs] + one manifest + one Android product flavor.
class FlavorConfig {
  final String appName;
  final String splashTitle;
  final String splashTagline;

  /// Material 3 seed color + key brand accents.
  final Color primary;
  final Color secondary;
  final Color accent;

  /// Gradient used by the splash screen / headers.
  final List<Color> brandGradient;

  /// Asset path of the pre-made artwork manifest for this flavor.
  final String manifestPath;

  /// Monetization toggles, applied to [AppConfig] at bootstrap.
  final bool adsEnabled;
  final bool iapEnabled;

  const FlavorConfig({
    required this.appName,
    required this.splashTitle,
    required this.splashTagline,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.brandGradient,
    required this.manifestPath,
    this.adsEnabled = true,
    this.iapEnabled = true,
  });

  static const Map<AppFlavor, FlavorConfig> _configs = {
    AppFlavor.original: FlavorConfig(
      appName: 'Pixely',
      splashTitle: 'Pixel Art',
      splashTagline: 'Color by Number',
      primary: Color(0xFF8A2BE2), // Indigo/Purple
      secondary: Color(0xFFFF007F), // Neon Pink
      accent: Color(0xFF00F0FF), // Cyber Cyan
      brandGradient: [Color(0xFF8A2BE2), Color(0xFFFF007F)],
      manifestPath: 'assets/pixel_art/manifest.json',
    ),
    AppFlavor.devotional: FlavorConfig(
      appName: 'Divine Pixels',
      splashTitle: 'Divine Pixels',
      splashTagline: 'Color the Divine',
      primary: Color(0xFFFF6D00), // Saffron
      secondary: Color(0xFFFFC107), // Temple Gold
      accent: Color(0xFF8E0000), // Deep Maroon
      brandGradient: [Color(0xFFFF6D00), Color(0xFF8E0000)],
      manifestPath: 'assets/pixel_art_devotional/manifest.json',
    ),
    AppFlavor.anime: FlavorConfig(
      appName: 'Anime Pixels',
      splashTitle: 'Anime Pixels',
      splashTagline: 'Color Your Heroes',
      primary: Color(0xFFFF4FA3), // Hot Pink
      secondary: Color(0xFF5AC8FA), // Sky Blue
      accent: Color(0xFFB14EFF), // Electric Violet
      brandGradient: [Color(0xFFFF4FA3), Color(0xFFB14EFF)],
      manifestPath: 'assets/pixel_art_anime/manifest.json',
    ),
    AppFlavor.pixelcalm: FlavorConfig(
      appName: 'PixelCalm',
      splashTitle: 'PixelCalm',
      splashTagline: 'Relax. Color. Breathe.',
      primary: Color(0xFF7C9070), // Sage
      secondary: Color(0xFFB08968), // Warm Clay
      accent: Color(0xFF5F8A8B), // Dusty Teal
      brandGradient: [Color(0xFF7C9070), Color(0xFF5F8A8B)],
      manifestPath: 'assets/pixel_art_pixelcalm/manifest.json',
      // Stress-relief audience: no ads, keep Pro/subscription IAP.
      adsEnabled: false,
    ),
  };

  static FlavorConfig of(AppFlavor flavor) => _configs[flavor]!;

  /// Convenience accessor for the active flavor's config.
  static FlavorConfig get current => of(currentFlavor);
}
