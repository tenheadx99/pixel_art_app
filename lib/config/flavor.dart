import 'package:flutter/material.dart';

/// Build flavors of the app. Selected at build time via
/// `--dart-define=FLAVOR=<name>` (defaults to [AppFlavor.original]).
enum AppFlavor { original, devotional, anime, pixelcalm, diamond, bible }

/// How filled cells are painted. [flat] is the classic color-by-number square;
/// [gem] renders a faceted "drill" for the diamond-painting flavor.
enum CellRenderStyle { flat, gem }

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
    case 'diamond':
      return AppFlavor.diamond;
    case 'bible':
      return AppFlavor.bible;
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

  final String appIconPath;

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

  /// Whether full-screen formats (interstitial + app-open) may show. Rewarded
  /// ads are governed by [adsEnabled] alone — they're user-initiated, so a
  /// flavor can offer them without interrupting the experience.
  final bool fullScreenAdsEnabled;

  /// Whether the passive banner may show. PixelCalm markets itself as free of
  /// ad interruptions, so it runs rewarded-only.
  final bool bannerAdsEnabled;

  /// How filled cells render. Defaults to the classic flat square so existing
  /// flavors are unchanged; the diamond flavor opts into [CellRenderStyle.gem].
  final CellRenderStyle cellStyle;

  /// Flavor-aware UI copy: the palette header and the "fill" action verb.
  final String paletteLabel;
  final String placeVerb;

  const FlavorConfig({
    required this.appName,
    required this.splashTitle,
    required this.splashTagline,
    required this.appIconPath,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.brandGradient,
    required this.manifestPath,
    this.adsEnabled = false,
    this.iapEnabled = true,
    this.fullScreenAdsEnabled = true,
    this.bannerAdsEnabled = true,
    this.cellStyle = CellRenderStyle.flat,
    this.paletteLabel = 'Select a Color',
    this.placeVerb = 'Fill',
  });

  static const Map<AppFlavor, FlavorConfig> _configs = {
    AppFlavor.original: FlavorConfig(
      appName: 'Pixely',
      splashTitle: 'Pixel Art',
      splashTagline: 'Color by Number',
      appIconPath: 'assets/icons/app_icon.png',
      primary: Color(0xFF8A2BE2), // Indigo/Purple
      secondary: Color(0xFFFF007F), // Neon Pink
      accent: Color(0xFF00F0FF), // Cyber Cyan
      brandGradient: [Color(0xFF8A2BE2), Color(0xFFFF007F)],
      manifestPath: 'assets/pixel_art/manifest.json',
      adsEnabled: false,
    ),
    AppFlavor.devotional: FlavorConfig(
      appName: 'Divine Pixels',
      splashTitle: 'Divine Pixels',
      splashTagline: 'Color the Divine',
      appIconPath: 'assets/icons/devotional.png',
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
      appIconPath: 'assets/icons/anime.png',
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
      appIconPath: 'assets/icons/pixelcalm.png',
      primary: Color(0xFF7C9070), // Sage
      secondary: Color(0xFFB08968), // Warm Clay
      accent: Color(0xFF5F8A8B), // Dusty Teal
      brandGradient: [Color(0xFF7C9070), Color(0xFF5F8A8B)],
      manifestPath: 'assets/pixel_art_pixelcalm/manifest.json',
      // Stress-relief audience whose store listing promises no ad
      // interruptions: rewarded-only (user-initiated) — no banner, no
      // interstitial/app-open.
      fullScreenAdsEnabled: false,
      bannerAdsEnabled: false,
    ),
    AppFlavor.bible: FlavorConfig(
      appName: 'Bible Pixels',
      splashTitle: 'Bible Pixels',
      splashTagline: 'Color the Word',
      appIconPath: 'assets/icons/bible.png',
      primary: Color(0xFF1A3FA8), // Royal Blue (stained glass)
      secondary: Color(0xFFE8B923), // Gold
      accent: Color(0xFF7B4FBF), // Violet
      brandGradient: [Color(0xFF1A3FA8), Color(0xFF7B4FBF)],
      manifestPath: 'assets/pixel_art_bible/manifest.json',
    ),
    AppFlavor.diamond: FlavorConfig(
      appName: 'Gem Art',
      splashTitle: 'Gem Art',
      splashTagline: 'Sparkle by Number',
      appIconPath: 'assets/icons/diamond.png',
      primary: Color(0xFF12C2E9), // Jewel Cyan
      secondary: Color(0xFFC471ED), // Amethyst
      accent: Color(0xFFF64F59), // Ruby
      brandGradient: [Color(0xFF12C2E9), Color(0xFFC471ED)],
      manifestPath: 'assets/pixel_art_diamond/manifest.json',
      adsEnabled: false,
      cellStyle: CellRenderStyle.gem,
      paletteLabel: 'Select a Drill',
      placeVerb: 'Place',
    ),
  };

  static FlavorConfig of(AppFlavor flavor) => _configs[flavor]!;

  /// Convenience accessor for the active flavor's config.
  static FlavorConfig get current => of(currentFlavor);

  /// Returns the RemoteConfig key for a given flavor and base key.
  static String getFlavorKey(AppFlavor flavor, String baseKey) {
    final prefix = flavor == AppFlavor.original ? 'pixelyart' : flavor.name;
    return '${prefix}_$baseKey';
  }
}
