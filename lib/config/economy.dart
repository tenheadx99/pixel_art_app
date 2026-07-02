import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/firestore_config_service.dart';

/// Runtime economy values: the admin panel's per-flavor Firestore overrides
/// (`pixel_art/{flavor}/config/economy`) with the historical [AppConstants]
/// values as fallback. Call sites use `Economy.x` instead of `AppConstants.x`
/// for every tunable; identifiers and doc keys match the admin panel.
class Economy {
  Economy._();

  static final FirestoreConfigService _config = FirestoreConfigService();

  static int _get(String key, int fallback) =>
      _config.economyInt(key) ?? fallback;

  // --- Earning diamonds ---
  static int get startingDiamonds => _get('startingDiamonds', 320);
  static int get diamondsPerCompletion =>
      _get('diamondsPerCompletion', AppConstants.diamondsPerCompletion);
  static int get diamondsDailyBonus =>
      _get('diamondsDailyBonus', AppConstants.diamondsDailyBonus);
  static int get diamondsPerLevelUp =>
      _get('diamondsPerLevelUp', AppConstants.diamondsPerLevelUp);
  static int get diamondsPerAchievement =>
      _get('diamondsPerAchievement', AppConstants.diamondsPerAchievement);
  static int get doubleRewardMultiplier =>
      _get('doubleRewardMultiplier', AppConstants.doubleRewardMultiplier);

  // --- Shop prices (in diamonds) ---
  static int get diamondCostUnlockArt =>
      _get('diamondCostUnlockArt', AppConstants.diamondCostUnlockArt);
  static int get diamondCostHint =>
      _get('diamondCostHint', AppConstants.diamondCostHint);
  static int get diamondCostWand =>
      _get('diamondCostWand', AppConstants.diamondCostWand);
  static int get diamondCostBomb =>
      _get('diamondCostBomb', AppConstants.diamondCostBomb);
  static int get diamondCostBrush =>
      _get('diamondCostBrush', AppConstants.diamondCostBrush);

  // --- Rewarded-ad and IAP grants ---
  static int get hintsPerRewardedAd =>
      _get('hintsPerRewardedAd', AppConstants.hintsPerRewardedAd);
  static int get wandsPerRewardedAd =>
      _get('wandsPerRewardedAd', AppConstants.wandsPerRewardedAd);
  static int get hintsPerPurchase =>
      _get('hintsPerPurchase', AppConstants.hintsPerPurchase);
  static int get wandsPerPurchase =>
      _get('wandsPerPurchase', AppConstants.wandsPerPurchase);

  // --- XP & levels ---
  static int get xpPerCell => _get('xpPerCell', AppConstants.xpPerCell);
  static int get xpPerCompletion =>
      _get('xpPerCompletion', AppConstants.xpPerCompletion);
  static int get xpLevelDivisor =>
      _get('xpLevelDivisor', AppConstants.xpLevelDivisor);

  // --- Milestone gifts (30% / 65% / 100%) ---
  static int get milestone30Bomb =>
      _get('milestone30Bomb', AppConstants.milestone30Bomb);
  static int get milestone65Diamonds =>
      _get('milestone65Diamonds', AppConstants.milestone65Diamonds);
  static int get milestone100Diamonds =>
      _get('milestone100Diamonds', AppConstants.milestone100Diamonds);
}
