import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appStoreId = 'com.europosit.pixelart';
  static const String appStoreUrl =
      'https://play.google.com/store/apps/details?id=com.europosit.pixelart';
  static const String privacyPolicyUrl = 'https://easybrain.com/privacy';
  static const String termsUrl = 'https://easybrain.com/terms';

  static const List<int> supportedGridSizes = [16, 24, 32, 48];

  static const String dbName = 'pixel_art.db';
  static const int dbVersion = 1;

  static const String galleryPrefKey = 'saved_artworks';
  static const String proPrefKey = 'is_pro_user';
  static const String darkModePrefKey = 'is_dark_mode';
  static const String completedIdsPrefKey = 'completed_ids';
  static const String inProgressPrefKey = 'in_progress';

  static const Map<int, Color> defaultPalette = {
    1: Color(0xFFFF0000),
    2: Color(0xFF00AA00),
    3: Color(0xFF0000FF),
    4: Color(0xFFFFFF00),
    5: Color(0xFFFF8800),
    6: Color(0xFF8800FF),
    7: Color(0xFF00AAAA),
    8: Color(0xFFFF00FF),
    9: Color(0xFFAA0000),
    10: Color(0xFF00FF00),
    11: Color(0xFF0088FF),
    12: Color(0xFFFFAA00),
    13: Color(0xFF880000),
    14: Color(0xFF006600),
    15: Color(0xFF440088),
    16: Color(0xFF888888),
  };

  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String appOpenAdUnitId =
      'ca-app-pub-3940256099942544/3419835294';

  static const String proProductId = 'pixel_art_pro';
  static const String hintProductId = 'pixel_art_hints_5';
}
