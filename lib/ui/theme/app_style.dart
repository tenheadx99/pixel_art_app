import 'package:flutter/material.dart';
import '../../config/flavor.dart';
import '../widgets/transitions.dart';

class AppStyle {
  // Default (original flavor) brand colors. The active Material 3 seed is
  // resolved per-flavor via [brandSeed]; these constants remain for the many
  // const gradient/shadow usages across the UI.
  static const Color primary = Color(0xFF8A2BE2); // Indigo/Purple
  static const Color secondary = Color(0xFFFF007F); // Neon Pink
  static const Color accent = Color(0xFF00F0FF); // Cyber Cyan

  /// Material 3 seed color for the active flavor.
  static Color get brandSeed => FlavorConfig.current.primary;
  static const Color gold = Color(0xFFFFD700);
  static const Color coral = Color(0xFFFF4757);
  static const Color lavender = Color(0xFFBD93F9);
  static const Color mint = Color(0xFF2ED573);
  static const Color peach = Color(0xFFFFBE2E);
  static const Color sky = Color(0xFF70A1FF);

  static const List<Color> gradientStart = [
    Color(0xFF8A2BE2),
    Color(0xFFFF007F),
  ];
  static const List<Color> gradientEnd = [Color(0xFF00F0FF), Color(0xFF8A2BE2)];

  /// Warm, near-black base used for the calm dark theme and chrome gradients.
  static const Color darkBg = Color(0xFF14141F);

  /// Calm header gradient derived from the active flavor's seed so each brand
  /// keeps its identity, but desaturated + dimmed so it reads as restful rather
  /// than a high-contrast neon ramp. Easing from the dark background into a
  /// softened brand tone.
  static List<Color> get headerGradient {
    final calm = mute(brandSeed, saturation: 0.55, lightnessFactor: 0.6);
    return [
      darkBg,
      Color.lerp(darkBg, calm, 0.7)!,
      calm,
    ];
  }

  /// Softened warm gradient (muted clay → peach → sand) for the daily banner.
  static const List<Color> sunsetGradient = [
    Color(0xFFD98E73),
    Color(0xFFE0A88B),
    Color(0xFFE8C9A0),
  ];

  /// Desaturate + dim a brand color so it can be used as calm chrome without
  /// losing its hue/identity.
  static Color mute(
    Color c, {
    double saturation = 0.6,
    double lightnessFactor = 1.0,
  }) {
    final h = HSLColor.fromColor(c);
    return h
        .withSaturation((h.saturation * saturation).clamp(0.0, 1.0))
        .withLightness((h.lightness * lightnessFactor).clamp(0.0, 1.0))
        .toColor();
  }

  /// Soft, neutral shadow for gentle depth instead of bright colored glows.
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(40),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static const List<Color> paletteColors = [
    Color(0xFFFF0000),
    Color(0xFFFF6B00),
    Color(0xFFFFD700),
    Color(0xFF00CC00),
    Color(0xFF0088FF),
    Color(0xFF6C00FF),
    Color(0xFFFF00FF),
    Color(0xFF00CCCC),
    Color(0xFFFF4488),
    Color(0xFF884400),
    Color(0xFF666666),
    Color(0xFF000000),
  ];

  static Color numberToColor(int number) {
    final colors = paletteColors;
    return colors[(number - 1) % colors.length];
  }

  /// One fade-through spec for every default route and back-navigation,
  /// matching [fadeThroughRoute] so pushes and pops read identically.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
    },
  );

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: brandSeed,
      pageTransitionsTheme: _pageTransitions,
      scaffoldBackgroundColor: const Color(0xFFF3F4F6), // Premium Platinum
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: primary.withAlpha(30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: primary.withAlpha(40),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: brandSeed,
      pageTransitionsTheme: _pageTransitions,
      scaffoldBackgroundColor: darkBg, // Warm deep slate (calm)
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E2C), // Lifted surface for gentle depth
        shadowColor: Colors.black.withAlpha(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: brandSeed,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static BoxDecoration gradientCard({List<Color>? colors, double radius = 20}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors ?? [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: (colors?.first ?? primary).withAlpha(40),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  static BoxDecoration glassmorphism(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.withAlpha(230)
          : Colors.white.withAlpha(25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withAlpha(60), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static Shader get shimmerGradient => const LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x66FFFFFF), Color(0x33FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  ).createShader(Rect.fromLTWH(0, 0, 200, 100));
}

class AppColors {
  static const List<Color> categoryColors = [
    Color(0xFF8A2BE2), // Indigo
    Color(0xFFFF007F), // Neon Pink
    Color(0xFF00F0FF), // Cyber Cyan
    Color(0xFFFF5E36), // Sunset Orange
    Color(0xFFBD93F9), // Lavender
    Color(0xFF50FA7B), // Pastel Emerald
    Color(0xFFFFB86C), // Pastel Amber
    Color(0xFF8BE9FD), // Electric Blue
  ];

  static List<Color> gradientForIndex(int index) {
    final i = index % categoryColors.length;
    final next = (i + 1) % categoryColors.length;
    return [categoryColors[i], categoryColors[next]];
  }
}
