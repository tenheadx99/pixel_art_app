import 'flavor.dart';

class AppConfig {
  static bool disableAds = false;
  static bool disableIap = false;
  static bool showAds = false;

  /// Display name of the active flavor (e.g. "Pixely" / "Divine Pixels").
  static String get appName => FlavorConfig.current.appName;
  static const int maxUndoSteps = 20;
  static const double defaultCellSize = 24.0;
  // Small enough that even a 128x128 grid fits the screen at fit-zoom;
  // readability at low zoom is handled by the LOD effect (numbers hide,
  // grayscale preview shows).
  static const double minCellSize = 2.0;
  static const double maxCellSize = 60.0;
  static const Duration autoSaveDelay = Duration(milliseconds: 700);
  static const double completionThreshold = 1.0;
}
