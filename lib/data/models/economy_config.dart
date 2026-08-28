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
  final String monthlyProductId;
  final String yearlyProductId;
  final String lifetimeProductId;
  final String yearlyBadge;
  final String monthlyBadge;
  final String offerText;
  final String monthlyFallbackPrice;
  final String yearlyFallbackPrice;
  final String lifetimeFallbackPrice;
  final List<String> features;

  const PaywallConfig({
    this.monthlyProductId = 'pixel_art_plus_monthly',
    this.yearlyProductId = 'pixel_art_plus_yearly',
    this.lifetimeProductId = 'pixel_art_pro_lifetime',
    this.yearlyBadge = 'SAVE 50%',
    this.monthlyBadge = '',
    this.offerText = 'Color everything. No interruptions.',
    this.monthlyFallbackPrice = '\$4.99/mo',
    this.yearlyFallbackPrice = '\$29.99/yr',
    this.lifetimeFallbackPrice = '\$49.99',
    this.features = const [
      'Every premium artwork unlocked',
      'All ads removed',
      '+50 diamonds every day',
      'Support new artwork packs',
    ],
  });

  factory PaywallConfig.fromMap(Map<String, dynamic> map) {
    List<String> feats = const [
      'Every premium artwork unlocked',
      'All ads removed',
      '+50 diamonds every day',
      'Support new artwork packs',
    ];
    if (map['features'] is List) {
      feats = (map['features'] as List).map((e) => e.toString()).toList();
    }

    return PaywallConfig(
      monthlyProductId:
          map['monthlyProductId'] as String? ?? 'pixel_art_plus_monthly',
      yearlyProductId:
          map['yearlyProductId'] as String? ?? 'pixel_art_plus_yearly',
      lifetimeProductId:
          map['lifetimeProductId'] as String? ?? 'pixel_art_pro_lifetime',
      yearlyBadge: map['yearlyBadge'] as String? ?? 'SAVE 50%',
      monthlyBadge: map['monthlyBadge'] as String? ?? '',
      offerText: map['offerText'] as String? ??
          'Color everything. No interruptions.',
      monthlyFallbackPrice:
          map['monthlyFallbackPrice'] as String? ?? '\$4.99/mo',
      yearlyFallbackPrice:
          map['yearlyFallbackPrice'] as String? ?? '\$29.99/yr',
      lifetimeFallbackPrice:
          map['lifetimeFallbackPrice'] as String? ?? '\$49.99',
      features: feats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthlyProductId': monthlyProductId,
      'yearlyProductId': yearlyProductId,
      'lifetimeProductId': lifetimeProductId,
      'yearlyBadge': yearlyBadge,
      'monthlyBadge': monthlyBadge,
      'offerText': offerText,
      'monthlyFallbackPrice': monthlyFallbackPrice,
      'yearlyFallbackPrice': yearlyFallbackPrice,
      'lifetimeFallbackPrice': lifetimeFallbackPrice,
      'features': features,
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
      diamondPacks: packs,
      paywall: paywall,
    );
  }
}
