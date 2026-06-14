import 'package:flutter/material.dart';

/// Build flavors of the app. Selected at build time via
/// `--dart-define=FLAVOR=devotional` (defaults to [AppFlavor.original]).
enum AppFlavor { original, devotional }

/// Resolved once from the compile-time environment.
const String _flavorName = String.fromEnvironment(
  'FLAVOR',
  defaultValue: 'original',
);

AppFlavor get currentFlavor {
  switch (_flavorName) {
    case 'devotional':
      return AppFlavor.devotional;
    case 'original':
    default:
      return AppFlavor.original;
  }
}

/// Per-flavor branding, theming and content routing. Keep all
/// flavor-specific values here so the rest of the app reads from
/// [FlavorConfig.of(currentFlavor)] rather than hardcoding.
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

  const FlavorConfig({
    required this.appName,
    required this.splashTitle,
    required this.splashTagline,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.brandGradient,
    required this.manifestPath,
  });

  static const FlavorConfig _original = FlavorConfig(
    appName: 'Pixely',
    splashTitle: 'Pixel Art',
    splashTagline: 'Color by Number',
    primary: Color(0xFF8A2BE2), // Indigo/Purple
    secondary: Color(0xFFFF007F), // Neon Pink
    accent: Color(0xFF00F0FF), // Cyber Cyan
    brandGradient: [Color(0xFF8A2BE2), Color(0xFFFF007F)],
    manifestPath: 'assets/pixel_art/manifest.json',
  );

  static const FlavorConfig _devotional = FlavorConfig(
    appName: 'Divine Pixels',
    splashTitle: 'Divine Pixels',
    splashTagline: 'Color the Divine',
    primary: Color(0xFFFF6D00), // Saffron
    secondary: Color(0xFFFFC107), // Temple Gold
    accent: Color(0xFF8E0000), // Deep Maroon
    brandGradient: [Color(0xFFFF6D00), Color(0xFF8E0000)],
    manifestPath: 'assets/pixel_art_devotional/manifest.json',
  );

  static FlavorConfig of(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.devotional:
        return _devotional;
      case AppFlavor.original:
        return _original;
    }
  }

  /// Convenience accessor for the active flavor's config.
  static FlavorConfig get current => of(currentFlavor);
}
