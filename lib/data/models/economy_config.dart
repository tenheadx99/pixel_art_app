class DiamondPackConfig {
  final String productId;
  final int amount; // Base diamonds (e.g. 3000)
  final int bonusPercentage; // Bonus percentage configured by Admin (e.g. 100 for +100%, 50 for +50%)
  final int bonusDiamonds; // Explicit bonus diamond count (if specified by Admin)
  final String title;
  final String badge;
  final String bonusText;
  final bool isFeatured;
  final int bonusBombs;
  final int bonusWands;

  const DiamondPackConfig({
    required this.productId,
    required this.amount,
    this.bonusPercentage = 0,
    this.bonusDiamonds = 0,
    required this.title,
    this.badge = '',
    this.bonusText = '',
    this.isFeatured = false,
    this.bonusBombs = 0,
    this.bonusWands = 0,
  });

  /// Calculates extra bonus diamonds granted based on explicit bonusDiamonds,
  /// bonusPercentage, or parsing percentages from bonusText (e.g. "+100% EXTRA").
  int get calculatedBonusDiamonds {
    if (bonusDiamonds > 0) return bonusDiamonds;
    if (bonusPercentage > 0) {
      return (amount * (bonusPercentage / 100)).round();
    }
    // Fallback: Parse percentage from bonusText string if Admin set e.g. "+100% EXTRA"
    if (bonusText.contains('%')) {
      final match = RegExp(r'(\d+)%').firstMatch(bonusText);
      if (match != null) {
        final pct = int.tryParse(match.group(1) ?? '') ?? 0;
        if (pct > 0) {
          return (amount * (pct / 100)).round();
        }
      }
    }
    return 0;
  }

  /// Total diamonds credited to user (Base Amount + Bonus Diamonds).
  /// e.g. 3000 Base + 100% Bonus (3000) = 6000 Total Diamonds!
  int get totalDiamonds => amount + calculatedBonusDiamonds;

  /// Formatted string showing real base amount + extra bonus diamonds if bonus exists, e.g. "3000 + 3000 Extra 💎"
  String get displayAmountWithBonus {
    if (calculatedBonusDiamonds > 0) {
      return '$amount + $calculatedBonusDiamonds Extra';
    }
    return '$amount Diamonds';
  }

  factory DiamondPackConfig.fromMap(Map<String, dynamic> map) {
    return DiamondPackConfig(
      productId: map['productId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      bonusPercentage: (map['bonusPercentage'] as num?)?.toInt() ?? 0,
      bonusDiamonds: (map['bonusDiamonds'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      badge: map['badge'] as String? ?? '',
      bonusText: map['bonusText'] as String? ?? '',
      isFeatured: map['isFeatured'] as bool? ?? false,
      bonusBombs: (map['bonusBombs'] as num?)?.toInt() ?? 0,
      bonusWands: (map['bonusWands'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'amount': amount,
      'bonusPercentage': bonusPercentage,
      'bonusDiamonds': bonusDiamonds,
      'title': title,
      'badge': badge,
      'bonusText': bonusText,
      'isFeatured': isFeatured,
      'bonusBombs': bonusBombs,
      'bonusWands': bonusWands,
    };
  }
}

class PaywallConfig {
  final String plus1DayProductId;
  final String plusWeeklyProductId;
  final String plusMonthlyProductId;
  final String plusYearlyProductId;
  final String removeAdsProductId;
  final String lifetimeProductId;

  final String plus1DayFallbackPrice;
  final String plusWeeklyFallbackPrice;
  final String plusMonthlyFallbackPrice;
  final String plusYearlyFallbackPrice;
  final String removeAdsFallbackPrice;
  final String lifetimeFallbackPrice;

  final String plus1DayOffer;
  final String plusWeeklyOffer;
  final String plusMonthlyOffer;
  final String plusYearlyOffer;
  final String removeAdsOffer;
  final String defaultPlan;
  final bool show1DayPlan;
  final bool showWeeklyPlan;
  final bool showMonthlyPlan;
  final bool showYearlyPlan;
  final bool showRemoveAdsPlan;
  final bool showLifetimePlan;
  final bool showUrgencyTimer;
  final int urgencyDurationHours;
  final String urgencyHeadline;

  // Backward-compatible getters
  String get monthlyProductId => plusMonthlyProductId;
  String get yearlyProductId => plusYearlyProductId;

  const PaywallConfig({
    this.plus1DayProductId = 'pixel_art_plus_1day',
    this.plusWeeklyProductId = 'pixel_art_plus_weekly',
    this.plusMonthlyProductId = 'pixel_art_plus_monthly',
    this.plusYearlyProductId = 'pixel_art_plus_yearly',
    this.removeAdsProductId = 'pixel_art_remove_ads',
    this.lifetimeProductId = 'pixel_art_pro',
    this.plus1DayFallbackPrice = '\$0.99 / day',
    this.plusWeeklyFallbackPrice = '\$2.99 / wk',
    this.plusMonthlyFallbackPrice = '\$7.99 / mo',
    this.plusYearlyFallbackPrice = '\$29.99 / yr',
    this.removeAdsFallbackPrice = '\$4.99',
    this.lifetimeFallbackPrice = '\$19.99',
    this.plus1DayOffer = '24-Hour Pass',
    this.plusWeeklyOffer = '7 Days Free Trial',
    this.plusMonthlyOffer = 'Most Popular',
    this.plusYearlyOffer = 'Save 65% Best Value',
    this.removeAdsOffer = 'One-Time Purchase',
    this.defaultPlan = 'yearly',
    this.show1DayPlan = true,
    this.showWeeklyPlan = true,
    this.showMonthlyPlan = true,
    this.showYearlyPlan = true,
    this.showRemoveAdsPlan = true,
    this.showLifetimePlan = true,
    this.showUrgencyTimer = true,
    this.urgencyDurationHours = 24,
    this.urgencyHeadline = 'Special Welcome Offer • 65% OFF',
  });

  factory PaywallConfig.fromMap(Map<String, dynamic> map) {
    final m = (map['paywall'] is Map<String, dynamic>)
        ? map['paywall'] as Map<String, dynamic>
        : map;

    String g(String key, String fallback) {
      final v = m[key] ?? map[key];
      return (v is String && v.isNotEmpty) ? v : fallback;
    }

    return PaywallConfig(
      plus1DayProductId: g('plus_1day_product_id', 'pixel_art_plus_1day'),
      plusWeeklyProductId: g('plus_weekly_product_id', 'pixel_art_plus_weekly'),
      plusMonthlyProductId: g('plus_monthly_product_id', 'pixel_art_plus_monthly'),
      plusYearlyProductId: g('plus_yearly_product_id', 'pixel_art_plus_yearly'),
      removeAdsProductId: g('remove_ads_product_id', 'pixel_art_remove_ads'),
      lifetimeProductId: g('pro_product_id', 'pixel_art_pro'),
      plus1DayFallbackPrice: g('plus_1day_price', '\$0.99 / day'),
      plusWeeklyFallbackPrice: g('plus_weekly_price', '\$2.99 / wk'),
      plusMonthlyFallbackPrice: g('plus_monthly_price', '\$7.99 / mo'),
      plusYearlyFallbackPrice: g('plus_yearly_price', '\$29.99 / yr'),
      removeAdsFallbackPrice: g('remove_ads_price', '\$4.99'),
      lifetimeFallbackPrice: g('lifetime_pro_price', '\$19.99'),
      plus1DayOffer: g('plus_1day_offer', '24-Hour Pass'),
      plusWeeklyOffer: g('plus_weekly_offer', '7 Days Free Trial'),
      plusMonthlyOffer: g('plus_monthly_offer', 'Most Popular'),
      plusYearlyOffer: g('plus_yearly_offer', 'Save 65% Best Value'),
      removeAdsOffer: g('remove_ads_offer', 'One-Time Purchase'),
      defaultPlan: g('default_plan', 'yearly'),
      show1DayPlan: m['show_1day_plan'] as bool? ?? true,
      showWeeklyPlan: m['show_weekly_plan'] as bool? ?? true,
      showMonthlyPlan: m['show_monthly_plan'] as bool? ?? true,
      showYearlyPlan: m['show_yearly_plan'] as bool? ?? true,
      showRemoveAdsPlan: m['show_remove_ads_plan'] as bool? ?? true,
      showLifetimePlan: m['show_lifetime_plan'] as bool? ?? true,
      showUrgencyTimer: m['show_urgency_timer'] as bool? ?? true,
      urgencyDurationHours: (m['urgency_duration_hours'] as num?)?.toInt() ?? 24,
      urgencyHeadline: g('urgency_headline', 'Special Welcome Offer • 65% OFF'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plus_1day_product_id': plus1DayProductId,
      'plus_weekly_product_id': plusWeeklyProductId,
      'plus_monthly_product_id': plusMonthlyProductId,
      'plus_yearly_product_id': plusYearlyProductId,
      'remove_ads_product_id': removeAdsProductId,
      'pro_product_id': lifetimeProductId,
      'plus_1day_price': plus1DayFallbackPrice,
      'plus_weekly_price': plusWeeklyFallbackPrice,
      'plus_monthly_price': plusMonthlyFallbackPrice,
      'plus_yearly_price': plusYearlyFallbackPrice,
      'remove_ads_price': removeAdsFallbackPrice,
      'lifetime_pro_price': lifetimeFallbackPrice,
      'plus_1day_offer': plus1DayOffer,
      'plus_weekly_offer': plusWeeklyOffer,
      'plus_monthly_offer': plusMonthlyOffer,
      'plus_yearly_offer': plusYearlyOffer,
      'remove_ads_offer': removeAdsOffer,
      'default_plan': defaultPlan,
      'show_1day_plan': show1DayPlan,
      'show_weekly_plan': showWeeklyPlan,
      'show_monthly_plan': showMonthlyPlan,
      'show_yearly_plan': showYearlyPlan,
      'show_remove_ads_plan': showRemoveAdsPlan,
      'show_lifetime_plan': showLifetimePlan,
      'show_urgency_timer': showUrgencyTimer,
      'urgency_duration_hours': urgencyDurationHours,
      'urgency_headline': urgencyHeadline,
    };
  }
}

class EconomyConfig {
  final int startingDiamonds;
  final int diamondsPerCompletion;
  final int diamondsDailyBonus;
  final int diamondsPerLevelUp;
  final int diamondsPerAchievement;
  final int doubleRewardMultiplier;

  // Shop prices in diamonds.
  final int diamondCostUnlockArt;
  final int diamondCostHint;
  final int diamondCostWand;
  final int diamondCostBomb;
  final int diamondCostBrush;

  // Shop availability toggle
  final bool isShopEnabled;

  // Dynamic IAP Diamond Packs.
  final List<DiamondPackConfig> diamondPacks;

  // Dynamic Paywall & Plus Subscription Config.
  final PaywallConfig paywall;

  const EconomyConfig({
    required this.startingDiamonds,
    required this.diamondsPerCompletion,
    required this.diamondsDailyBonus,
    required this.diamondsPerLevelUp,
    required this.diamondsPerAchievement,
    required this.doubleRewardMultiplier,
    required this.diamondCostUnlockArt,
    required this.diamondCostHint,
    required this.diamondCostWand,
    required this.diamondCostBomb,
    required this.diamondCostBrush,
    this.isShopEnabled = true,
    this.diamondPacks = defaultDiamondPacks,
    this.paywall = const PaywallConfig(),
  });

  static const List<DiamondPackConfig> defaultDiamondPacks = [
    DiamondPackConfig(
      productId: 'pixel_art_diamonds_starter',
      amount: 500,
      title: 'Starter Pack',
      badge: '80% OFF',
      bonusText: 'SPECIAL BUNDLE',
      isFeatured: false,
      bonusBombs: 3,
      bonusWands: 3,
    ),
    DiamondPackConfig(
      productId: 'pixel_art_diamonds_500',
      amount: 500,
      title: 'Handful of Diamonds',
      badge: '',
      bonusText: '',
      isFeatured: false,
    ),
    DiamondPackConfig(
      productId: 'pixel_art_diamonds_1200',
      amount: 1200,
      bonusPercentage: 50,
      title: 'Bag of Diamonds',
      badge: 'MOST POPULAR',
      bonusText: '+50% EXTRA',
      isFeatured: true,
    ),
    DiamondPackConfig(
      productId: 'pixel_art_diamonds_3000',
      amount: 3000,
      bonusPercentage: 100,
      title: 'Chest of Diamonds',
      badge: 'BEST VALUE',
      bonusText: '+100% EXTRA',
      isFeatured: false,
    ),
  ];

  static const EconomyConfig defaults = EconomyConfig(
    startingDiamonds: 320,
    diamondsPerCompletion: 50,
    diamondsDailyBonus: 25,
    diamondsPerLevelUp: 50,
    diamondsPerAchievement: 15,
    doubleRewardMultiplier: 2,
    diamondCostUnlockArt: 200,
    diamondCostHint: 30,
    diamondCostWand: 40,
    diamondCostBomb: 40,
    diamondCostBrush: 40,
    isShopEnabled: true,
    diamondPacks: defaultDiamondPacks,
    paywall: PaywallConfig(),
  );

  factory EconomyConfig.fromMap(Map<String, dynamic> map) {
    int f(String key, int fallback) {
      final v = (map[key] as num?)?.toInt();
      return (v == null || v < 0) ? fallback : v;
    }

    const d = defaults;

    List<DiamondPackConfig> packs = defaultDiamondPacks;
    if (map['diamondPacks'] is List) {
      final rawList = map['diamondPacks'] as List;
      final parsed = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => DiamondPackConfig.fromMap(e))
          .where((p) => p.productId.isNotEmpty && p.amount > 0)
          .toList();
      if (parsed.isNotEmpty) {
        packs = parsed;
      }
    }

    PaywallConfig paywall = d.paywall;
    if (map['paywall'] is Map<String, dynamic>) {
      paywall = PaywallConfig.fromMap(map['paywall'] as Map<String, dynamic>);
    }

    final bool isShopEnabled = map['isShopEnabled'] as bool? ??
        map['shopEnabled'] as bool? ??
        d.isShopEnabled;

    return EconomyConfig(
      startingDiamonds: f('startingDiamonds', d.startingDiamonds),
      diamondsPerCompletion:
          f('diamondsPerCompletion', d.diamondsPerCompletion),
      diamondsDailyBonus: f('diamondsDailyBonus', d.diamondsDailyBonus),
      diamondsPerLevelUp: f('diamondsPerLevelUp', d.diamondsPerLevelUp),
      diamondsPerAchievement:
          f('diamondsPerAchievement', d.diamondsPerAchievement),
      doubleRewardMultiplier:
          f('doubleRewardMultiplier', d.doubleRewardMultiplier),
      diamondCostUnlockArt: f('diamondCostUnlockArt', d.diamondCostUnlockArt),
      diamondCostHint: f('diamondCostHint', d.diamondCostHint),
      diamondCostWand: f('diamondCostWand', d.diamondCostWand),
      diamondCostBomb: f('diamondCostBomb', d.diamondCostBomb),
      diamondCostBrush: f('diamondCostBrush', d.diamondCostBrush),
      isShopEnabled: isShopEnabled,
      diamondPacks: packs,
      paywall: paywall,
    );
  }
}
