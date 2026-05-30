class AppConfig {
  static bool disableAds = false;
  static bool disableIap = false;
  static bool showAds = false;


  static const String appName = 'PixelyArt';
  static const int maxUndoSteps = 20;
  static const double defaultCellSize = 24.0;
  static const double minCellSize = 12.0;
  static const double maxCellSize = 60.0;
  static const Duration autoSaveDelay = Duration(milliseconds: 700);
  static const double completionThreshold = 1.0;
}
