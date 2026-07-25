import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appStoreId = 'com.tenhead.pixelyart';
  static const String appStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tenhead.pixelyart';
  static const String privacyPolicyUrl =
      'https://pixelcolorapps.web.app/privacy-policy.html';
  static const String termsUrl =
      'https://pixelcolorapps.web.app/terms-of-service.html';

  static const List<int> supportedGridSizes = [16, 24, 32, 48, 64];

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

  // Production AdMob unit IDs — used as local fallback when Remote Config
  // has not yet fetched / has no value. These must match the defaults set in
  // remote_config_service.dart so both paths serve real (non-test) ads.
  static const String bannerAdUnitId =
      'ca-app-pub-9064606616675657/7511066180';
  static const String interstitialAdUnitId =
      'ca-app-pub-9064606616675657/6197984517';
  static const String rewardedAdUnitId =
      'ca-app-pub-9064606616675657/4884902843';
  static const String appOpenAdUnitId =
      'ca-app-pub-9064606616675657/4258216888';

  static const String proProductId = 'pixel_art_pro';
  static const String hintProductId = 'pixel_art_hints_5';
  static const String wandPackProductId = 'pixel_art_wands_10';

  // --- Plus subscription (remove ads + all premium art + daily diamonds) ---
  // Subscription products must be created in Play Console for every flavor's
  // app with these exact IDs.
  static const String plusMonthlyProductId = 'pixel_art_plus_monthly';
  static const String plusYearlyProductId = 'pixel_art_plus_yearly';

  // Entitlement is a local expiry stamp refreshed by purchase/restore events
  // each session (no server). The window exceeds the billing period by a few
  // grace days so offline stretches between store re-validations don't lapse
  // an active subscriber; a cancelled sub stops being restored and the stamp
  // runs out on its own.
  static const String plusExpiryPrefKey = 'plus_expiry_ms';
  static const int plusMonthlyEntitlementDays = 34;
  static const int plusYearlyEntitlementDays = 369;

  // Daily diamond stipend for Plus subscribers, claimed on first launch of
  // the day.
  static const int diamondsDailyPlusStipend = 25;
  static const String plusStipendDayPrefKey = 'plus_stipend_last_day';

  static const int hintsPerPurchase = 5;
  static const int wandsPerPurchase = 10;
  static const int hintsPerRewardedAd = 3;
  static const int wandsPerRewardedAd = 2;

  static const String magicWandsPrefKey = 'magic_wands_count';
  static const String hintsPrefKey = 'hints_available';

  // --- Diamond economy ---
  // Diamonds are earned by finishing artworks and spent in the in-canvas shop
  // on tools and hints. Award flags are stored per-art so a piece only ever
  // pays out once (re-completing after an erase won't double-reward).
  static const int diamondsPerCompletion = 50;
  static const int diamondsDailyBonus = 25;
  static const String diamondsAwardedPrefix = 'diamonds_awarded_';

  // Permanently unlock a single premium artwork with diamonds.
  static const int diamondCostUnlockArt = 200;

  // Shop prices (in diamonds).
  static const int diamondCostHint = 30;
  static const int diamondCostWand = 40;
  static const int diamondCostBomb = 40;
  static const int diamondCostBrush = 40;

  // --- XP & levels ---
  // XP is awarded in batch on completion (cells + a flat bonus) and on
  // milestone claims, never per-cell. Level grows on a gentle sqrt curve:
  // level = floor(sqrt(totalXp / xpLevelDivisor)) + 1.
  static const int xpPerCell = 1;
  static const int xpPerCompletion = 100;
  static const int xpLevelDivisor = 100;
  // Diamonds granted each time the player levels up.
  static const int diamondsPerLevelUp = 50;

  // --- In-artwork milestone gifts (progress bar at 30% / 65% / 100%) ---
  // Claimed milestones are tracked per-art so re-coloring never re-grants.
  static const String milestoneClaimedPrefix = 'milestones_claimed_';
  static const int milestone30Bomb = 1; // 30% -> a bomb tool
  static const int milestone65Diamonds = 20; // 65% -> diamonds
  static const int milestone100Diamonds = 30; // 100% -> diamonds

  // --- Other reward hooks ---
  static const int diamondsPerAchievement = 15;
  static const int doubleRewardMultiplier = 2; // "watch ad to 2x" payout

  // --- Joyful fill effects (overlay above the grid) ---
  static const int fillEffectLifetimeMs = 600; // how long one effect lives
  static const int fillEffectMaxConcurrent = 28; // hard cap (perf guard)
  static const int fillEffectStrokeThrottleMs = 45; // full effect rate on swipe
  // Combo "xN" callouts at these consecutive-fill counts.
  static const List<int> comboThresholds = [5, 10, 20, 35, 50];

  // How long a cell takes to "grow in" from the preview to full color (taps
  // only; strokes snap so fast swipes stay smooth). Cap bounds the registry.
  static const int fillGrowMs = 220;
  static const int fillGrowMaxCells = 64;
  // How long a fill's timestamp stays available after the flat-grid grow ends:
  // the gem shader's settle/glint/afterglow timeline (~0.55s) plus swipe
  // stagger headroom reads ages from this registry.
  static const int fillGrowRetentionMs = 700;
}
