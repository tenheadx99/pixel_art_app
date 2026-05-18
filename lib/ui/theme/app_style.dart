import 'package:flutter/material.dart';

class AppStyle {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFFD79A8);
  static const Color accent = Color(0xFF00CEC9);
  static const Color gold = Color(0xFFFFD700);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color lavender = Color(0xFFA29BFE);
  static const Color mint = Color(0xFF55EFC4);
  static const Color peach = Color(0xFFFFEAA7);
  static const Color sky = Color(0xFF74B9FF);

  static const List<Color> gradientStart = [Color(0xFF6C5CE7), Color(0xFFFD79A8)];
  static const List<Color> gradientEnd = [Color(0xFF00CEC9), Color(0xFF6C5CE7)];
  static const List<Color> headerGradient = [
    Color(0xFF6C5CE7),
    Color(0xFFA29BFE),
    Color(0xFFFD79A8),
  ];
  static const List<Color> sunsetGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
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

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: const Color(0xFFF8F9FF),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: primary.withAlpha(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: primary.withAlpha(80),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      fontFamily: 'Poppins',
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          color: (colors?.first ?? primary).withAlpha(80),
          blurRadius: 16,
          offset: const Offset(0, 6),
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
      border: Border.all(
        color: Colors.white.withAlpha(60),
        width: 1.5,
      ),
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
    Color(0xFF6C5CE7),
    Color(0xFFFD79A8),
    Color(0xFF00CEC9),
    Color(0xFFFF6B6B),
    Color(0xFFA29BFE),
    Color(0xFF55EFC4),
    Color(0xFFFFD93D),
    Color(0xFF74B9FF),
  ];

  static List<Color> gradientForIndex(int index) {
    final i = index % categoryColors.length;
    final next = (i + 1) % categoryColors.length;
    return [categoryColors[i], categoryColors[next]];
  }
}
