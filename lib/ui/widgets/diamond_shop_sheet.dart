import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/models/economy_config.dart';
import 'package:pixel_art_app/data/services/economy_config_service.dart';
import 'package:pixel_art_app/data/services/iap_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/coloring_provider.dart';

class DiamondShopSheet extends StatefulWidget {
  const DiamondShopSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DiamondShopSheet(),
    );
  }

  @override
  State<DiamondShopSheet> createState() => _DiamondShopSheetState();
}

class _DiamondShopSheetState extends State<DiamondShopSheet>
    with TickerProviderStateMixin {
  Map<String, ProductDetails> _storeProducts = {};
  bool _loadingStore = true;

  // Pulse glow animation for featured cards
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Continuous rotating diamond & spin burst on count change
  late AnimationController _diamondRotateController;
  late AnimationController _spinBurstController;
  late AnimationController _counterPulseController;

  // Floating delta text (+500 / -20) animation controller
  late AnimationController _deltaAnimController;
  int? _deltaDiamonds;
  int? _lastDiamondCount;

  // Shimmer effect animation controller for featured cards
  late AnimationController _shimmerController;

  // Toast animation controller (Slide down + Fade + Elastic scale)
  late AnimationController _toastAnimController;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastFadeAnimation;
  late Animation<double> _toastScaleAnimation;

  // In-sheet Toast & purchase state
  String? _toastMessage;
  bool _isToastError = false;
  Timer? _toastTimer;
  String? _buyingProductId;

  @override
  void initState() {
    super.initState();

    // Pulse animation controller for card glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // Continuous Diamond Rotation (slow 360 continuous spin)
    _diamondRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Spin burst when diamond count changes (1 full energetic turn)
    _spinBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Diamond Counter Pill Elastic Scale Pulse
    _counterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Floating delta popup (+X / -Y) float up and fade out
    _deltaAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Card Shimmer overlay animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Toast animation controller
    _toastAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toastAnimController,
      curve: Curves.easeOutBack,
    ));

    _toastFadeAnimation = CurvedAnimation(
      parent: _toastAnimController,
      curve: Curves.easeIn,
    );

    _toastScaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _toastAnimController,
      curve: Curves.easeOutBack,
    ));

    _loadStoreProducts();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _pulseController.dispose();
    _diamondRotateController.dispose();
    _spinBurstController.dispose();
    _counterPulseController.dispose();
    _deltaAnimController.dispose();
    _shimmerController.dispose();
    _toastAnimController.dispose();
    super.dispose();
  }

  void _onDiamondCountChanged(int delta) {
    if (!mounted) return;
    setState(() {
      _deltaDiamonds = delta;
    });
    _spinBurstController.forward(from: 0.0);
    _counterPulseController.forward(from: 0.0);
    _deltaAnimController.forward(from: 0.0);
  }

  void _showToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _toastMessage = message;
      _isToastError = isError;
    });

    _toastAnimController.forward(from: 0.0);

    _toastTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _toastAnimController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _toastMessage = null;
            });
          }
        });
      }
    });
  }

  Future<void> _handleBuyPack(
      DiamondPackConfig pack, AppSettingsProvider settings) async {
    if (_buyingProductId != null) return;
    setState(() => _buyingProductId = pack.productId);

    final storeProduct = _storeProducts[pack.productId];
    bool launched = false;

    if (storeProduct != null) {
      launched = await IAPService().buyProduct(storeProduct, consumable: true);
    } else {
      launched = await IAPService().buyDiamondPack(pack.productId);
    }

    if (launched) {
      _showToast('Connecting to Store…');
    } else {
      // Fallback in dev/testing mode: Grant total diamonds (Base + Admin configured bonus)
      settings.addDiamonds(pack.totalDiamonds);
      if (pack.bonusWands > 0) {
        settings.addWands(pack.bonusWands);
      }
      if (pack.bonusBombs > 0 && mounted) {
        context.read<ColoringProvider>().addBombs(pack.bonusBombs);
      }
      if (pack.calculatedBonusDiamonds > 0) {
        _showToast('Granted ${pack.amount} + ${pack.calculatedBonusDiamonds} Extra = ${pack.totalDiamonds} 💎 (Test Mode)');
      } else {
        _showToast('Granted ${pack.totalDiamonds} 💎 (Test Mode)');
      }
    }

    if (mounted) {
      setState(() => _buyingProductId = null);
    }
  }

  Future<void> _loadStoreProducts() async {
    final packs = EconomyConfigService().currentConfig.diamondPacks;
    final ids = packs.map((p) => p.productId).toSet();
    if (ids.isNotEmpty) {
      final products = await IAPService().getProductDetails(ids);
      if (mounted) {
        setState(() {
          _storeProducts = {for (final p in products) p.id: p};
          _loadingStore = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loadingStore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = FlavorConfig.current;
    final settings = context.watch<AppSettingsProvider>();
    final coloring = context.watch<ColoringProvider>();
    final economy = EconomyConfigService().currentConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bundlePacks = economy.diamondPacks
        .where((p) =>
            p.bonusBombs > 0 ||
            p.bonusWands > 0 ||
            p.productId.contains('starter'))
        .toList();
    final featuredPack = economy.diamondPacks.firstWhere(
      (p) => p.isFeatured || p.badge.contains('POPULAR'),
      orElse: () => economy.diamondPacks.length > 1
          ? economy.diamondPacks[1]
          : economy.diamondPacks.first,
    );
    final regularPacks = economy.diamondPacks
        .where((p) =>
            !bundlePacks.contains(p) && p.productId != featuredPack.productId)
        .toList();

    // Theme color palette derived from flavor
    final bgGradient = isDark
        ? [const Color(0xFF0F111E), const Color(0xFF191B2E)]
        : [const Color(0xFFF6F8FC), const Color(0xFFEBF0F8)];
    final cardBg = isDark ? const Color(0xFF1B1E32) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);

    // Track diamond count changes to trigger spin burst & floating delta pop-up
    final currentDiamonds = settings.diamondsAvailable;
    if (_lastDiamondCount != null && _lastDiamondCount != currentDiamonds) {
      final delta = currentDiamonds - _lastDiamondCount!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onDiamondCountChanged(delta);
      });
    }
    _lastDiamondCount = currentDiamonds;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: brand.primary.withValues(alpha: 0.4 + pulseVal * 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: brand.primary.withValues(alpha: 0.25),
                blurRadius: 25,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header with Diamond balance & Flavor badge
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        // Animated Continuous Rotating & Spin Burst Header Diamond Icon
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_diamondRotateController, _spinBurstController]),
                          builder: (context, child) {
                            final continuousAngle =
                                _diamondRotateController.value * 2 * math.pi;
                            final burstAngle =
                                _spinBurstController.value * 2 * math.pi;
                            return Transform.rotate(
                              angle: continuousAngle + burstAngle,
                              child: child,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: brand.brandGradient),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: brand.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.diamond_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diamond Shop',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              brand.appName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: brand.primary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Top Right Diamond Counter Pill with Elastic Pulse, Spin Icon, Rolling Ticker & Floating Delta
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerRight,
                          children: [
                            ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                                CurvedAnimation(
                                  parent: _counterPulseController,
                                  curve: Curves.elasticOut,
                                ),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      brand.primary.withValues(alpha: 0.2),
                                      brand.secondary.withValues(alpha: 0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (_deltaDiamonds != null &&
                                            _deltaDiamonds! > 0)
                                        ? Colors.greenAccent
                                        : (_deltaDiamonds != null &&
                                                _deltaDiamonds! < 0)
                                            ? Colors.orangeAccent
                                            : brand.primary.withValues(alpha: 0.5),
                                    width: _counterPulseController.isAnimating
                                        ? 2.0
                                        : 1.0,
                                  ),
                                  boxShadow: [
                                    if (_counterPulseController.isAnimating)
                                      BoxShadow(
                                        color: (_deltaDiamonds != null &&
                                                _deltaDiamonds! > 0)
                                            ? Colors.greenAccent
                                                .withValues(alpha: 0.5)
                                            : Colors.amberAccent
                                                .withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _diamondRotateController,
                                        _spinBurstController
                                      ]),
                                      builder: (context, child) {
                                        final angle =
                                            (_diamondRotateController.value *
                                                    2 *
                                                    math.pi) +
                                                (_spinBurstController.value *
                                                    2 *
                                                    math.pi);
                                        return Transform.rotate(
                                          angle: angle,
                                          child: Icon(
                                            Icons.diamond_rounded,
                                            color: brand.primary,
                                            size: 18,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: (currentDiamonds -
                                                (_deltaDiamonds ?? 0))
                                            .toDouble(),
                                        end: currentDiamonds.toDouble(),
                                      ),
                                      duration:
                                          const Duration(milliseconds: 650),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, child) {
                                        return Text(
                                          '${val.round()}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Floating Animated Delta (+500 💎 / -20 💎) Float-up & Fade Badge
                            if (_deltaDiamonds != null && _deltaDiamonds != 0)
                              Positioned(
                                top: -24,
                                right: 0,
                                child: AnimatedBuilder(
                                  animation: _deltaAnimController,
                                  builder: (context, child) {
                                    final progress = _deltaAnimController.value;
                                    final isPositive = _deltaDiamonds! > 0;
                                    final text = isPositive
                                        ? '+$_deltaDiamonds 💎'
                                        : '$_deltaDiamonds 💎';
                                    final color = isPositive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444);
                                    final bg = isPositive
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEE2E2);

                                    return Opacity(
                                      opacity:
                                          (1.0 - progress * 0.85).clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(0, -progress * 24),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? (isPositive
                                                    ? const Color(0xFF064E3B)
                                                    : const Color(0xFF7F1D1D))
                                                : bg,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: color, width: 1.2),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    color.withValues(alpha: 0.35),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              color:
                                                  isDark ? Colors.white : color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Divider(color: textColor.withValues(alpha: 0.1), height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- Section 1: Starter Pack Hero Banner ---
                        if (bundlePacks.isNotEmpty) ...[
                          for (final pack in bundlePacks) ...[
                            _buildStarterHeroBanner(context, pack, brand,
                                cardBg, textColor, pulseVal, settings),
                            const SizedBox(height: 16),
                          ],
                        ],

                        // --- Section 2: Featured "MOST POPULAR" Hero Card ---
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                color: Colors.amber, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Diamond Vault',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_loadingStore)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child:
                                  CircularProgressIndicator(color: Colors.amber),
                            ),
                          )
                        else ...[
                          // Featured Hero Pack Card
                          _buildFeaturedHeroCard(context, featuredPack, brand,
                              cardBg, textColor, pulseVal, settings),

                          const SizedBox(height: 12),

                          // Regular Packs Grid / Stack
                          _buildRegularPacksGrid(context, regularPacks, brand,
                              cardBg, textColor, pulseVal, settings),
                        ],

                        const SizedBox(height: 24),

                        // --- Section 3: Spend Diamonds on Boosters ---
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded,
                                color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tool & Booster Exchange',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Buy Bomb
                        _buildExchangeTile(
                          context: context,
                          title: 'Paint Bomb',
                          subtitle: 'Fills a 3x3 region instantly',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.deepOrangeAccent,
                          cost: economy.diamondCostBomb,
                          countOwned: coloring.bombsCount,
                          cardBg: cardBg,
                          textColor: textColor,
                          brand: brand,
                          onBuy: () {
                            if (coloring.buyBombWithDiamonds(settings)) {
                              _showToast(
                                  'Bought 1 Bomb for ${economy.diamondCostBomb} 💎! Bomb mode active.');
                            } else {
                              _showToast(
                                  'Not enough Diamonds! You need ${economy.diamondCostBomb} 💎.',
                                  isError: true);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // Buy Magic Wand
                        _buildExchangeTile(
                          context: context,
                          title: 'Magic Wand',
                          subtitle: 'Fills all matching cells of selected color',
                          icon: Icons.auto_fix_high_rounded,
                          iconColor: Colors.purpleAccent,
                          cost: economy.diamondCostWand,
                          countOwned: coloring.magicWandsCount,
                          cardBg: cardBg,
                          textColor: textColor,
                          brand: brand,
                          onBuy: () {
                            if (settings.useDiamonds(economy.diamondCostWand)) {
                              coloring.addMagicWands(1);
                              _showToast(
                                  'Bought 1 Magic Wand for ${economy.diamondCostWand} 💎!');
                            } else {
                              _showToast(
                                  'Not enough Diamonds! You need ${economy.diamondCostWand} 💎.',
                                  isError: true);
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // Buy Hints
                        _buildExchangeTile(
                          context: context,
                          title: 'Hint Pack',
                          subtitle: 'Reveals 5 hidden cells',
                          icon: Icons.lightbulb_rounded,
                          iconColor: Colors.amberAccent,
                          cost: economy.diamondCostHint,
                          countOwned: settings.hintsAvailable,
                          cardBg: cardBg,
                          textColor: textColor,
                          brand: brand,
                          onBuy: () {
                            if (settings.useDiamonds(economy.diamondCostHint)) {
                              settings.addHints(5);
                              _showToast(
                                  'Bought 5 Hints for ${economy.diamondCostHint} 💎!');
                            } else {
                              _showToast(
                                  'Not enough Diamonds! You need ${economy.diamondCostHint} 💎.',
                                  isError: true);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),

              // Animated Slide & Elastic Bounce In-Modal Toast Notification Banner
              if (_toastMessage != null)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: SlideTransition(
                    position: _toastSlideAnimation,
                    child: FadeTransition(
                      opacity: _toastFadeAnimation,
                      child: ScaleTransition(
                        scale: _toastScaleAnimation,
                        child: Material(
                          elevation: 12,
                          borderRadius: BorderRadius.circular(16),
                          color: _isToastError
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF2E7D32),
                          shadowColor: _isToastError
                              ? Colors.red.withValues(alpha: 0.4)
                              : Colors.green.withValues(alpha: 0.4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  _isToastError
                                      ? Icons.error_outline_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _toastMessage!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getPackPriceText(DiamondPackConfig pack) {
    final storeProduct = _storeProducts[pack.productId];
    if (storeProduct != null && storeProduct.price.isNotEmpty) {
      return storeProduct.price;
    }
    if (pack.productId.contains('starter')) return '\$0.99';
    if (pack.amount <= 500) return '\$1.99';
    if (pack.amount <= 1200) return '\$9.99';
    if (pack.amount <= 3000) return '\$19.99';
    return '\$4.99';
  }

  /// High-contrast bonus badge helper for light and dark theme visibility
  Widget _buildBonusBadgeText(String text, bool isDark) {
    final bg = isDark ? const Color(0xFF3D2400) : const Color(0xFFFFF3DC);
    final textCol = isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309);
    final borderCol = isDark ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.15),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textCol,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Full-Width Starter Hero Banner Card
  Widget _buildStarterHeroBanner(
    BuildContext context,
    DiamondPackConfig pack,
    FlavorConfig brand,
    Color cardBg,
    Color textColor,
    double pulseVal,
    AppSettingsProvider settings,
  ) {
    final priceText = _getPackPriceText(pack);
    final isBuying = _buyingProductId == pack.productId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF332000),
            Color(0xFF1E1300),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Color.lerp(Colors.amber.shade500, Colors.amber.shade300, pulseVal)!,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade600.withValues(alpha: 0.25 + pulseVal * 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.amber.shade700],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    pack.badge.isNotEmpty ? pack.badge : '🎁 80% OFF STARTER PACK',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (pack.bonusText.isNotEmpty)
                  _buildBonusBadgeText(pack.bonusText, isDark),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.shade400.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.cyanAccent.shade400.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                    Icons.diamond_rounded,
                    color: Colors.cyanAccent.shade400,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayAmountWithBonus,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (pack.bonusBombs > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.deepOrangeAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 13,
                                      color: Colors.deepOrangeAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${pack.bonusBombs} Bombs',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          if (pack.bonusWands > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.purpleAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_fix_high_rounded,
                                      size: 13, color: Colors.purpleAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${pack.bonusWands} Wands',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _AnimatedPressButton(
                  onTap: isBuying ? null : () => _handleBuyPack(pack, settings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade500,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.shade600.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: isBuying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            priceText,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Full-Width Featured Hero Card ("MOST POPULAR")
  Widget _buildFeaturedHeroCard(
    BuildContext context,
    DiamondPackConfig pack,
    FlavorConfig brand,
    Color cardBg,
    Color textColor,
    double pulseVal,
    AppSettingsProvider settings,
  ) {
    final priceText = _getPackPriceText(pack);
    final isBuying = _buyingProductId == pack.productId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Color.lerp(Colors.amber.shade500, Colors.amber.shade200, pulseVal)!,
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.25 + pulseVal * 0.2),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.amber.shade700],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.black),
                      const SizedBox(width: 4),
                      Text(
                        pack.badge.isNotEmpty ? pack.badge : 'MOST POPULAR',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (pack.bonusText.isNotEmpty)
                  _buildBonusBadgeText(pack.bonusText, isDark),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.shade400.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.diamond_rounded,
                    color: Colors.cyanAccent.shade400,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayAmountWithBonus,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pack.calculatedBonusDiamonds > 0
                            ? '${pack.title.isNotEmpty ? pack.title : "Vault Pack"} (${pack.totalDiamonds} Total 💎)'
                            : (pack.title.isNotEmpty ? pack.title : 'Vault Pack'),
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _AnimatedPressButton(
                  onTap: isBuying ? null : () => _handleBuyPack(pack, settings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade500,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: isBuying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            priceText,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Grid / Rows for Remaining Standard Diamond Packs
  Widget _buildRegularPacksGrid(
    BuildContext context,
    List<DiamondPackConfig> packs,
    FlavorConfig brand,
    Color cardBg,
    Color textColor,
    double pulseVal,
    AppSettingsProvider settings,
  ) {
    if (packs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final pack in packs) ...[
          _buildStandardPackRow(
              context, pack, brand, cardBg, textColor, pulseVal, settings),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStandardPackRow(
    BuildContext context,
    DiamondPackConfig pack,
    FlavorConfig brand,
    Color cardBg,
    Color textColor,
    double pulseVal,
    AppSettingsProvider settings,
  ) {
    final priceText = _getPackPriceText(pack);
    final isBuying = _buyingProductId == pack.productId;
    final isBestValue = pack.badge.toUpperCase().contains('BEST') ||
        pack.productId.contains('3000');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme values for Best Value vs Regular pack
    final borderColor = isBestValue
        ? Color.lerp(Colors.amber.shade500, Colors.amber.shade200, pulseVal)!
        : textColor.withValues(alpha: 0.15);
    final borderWidth = isBestValue ? 2.0 : 1.0;
    final boxShadow = isBestValue
        ? [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.2 + pulseVal * 0.15),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row for Badges (prevents overlap with right price button)
            if (pack.badge.isNotEmpty || pack.bonusText.isNotEmpty) ...[
              Row(
                children: [
                  if (pack.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: isBestValue
                            ? LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.amber.shade700
                                ],
                              )
                            : LinearGradient(
                                colors: [brand.primary, brand.secondary],
                              ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (isBestValue ? Colors.amber : brand.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBestValue
                                ? Icons.stars_rounded
                                : Icons.local_fire_department_rounded,
                            size: 13,
                            color: isBestValue ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pack.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isBestValue ? Colors.black : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (pack.bonusText.isNotEmpty)
                    _buildBonusBadgeText(pack.bonusText, isDark),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Content Row: Diamond Icon, Title/Amount & Price CTA Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isBestValue
                        ? Colors.cyanAccent.shade400.withValues(alpha: 0.15)
                        : brand.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.diamond_rounded,
                    color: isBestValue
                        ? Colors.cyanAccent.shade400
                        : brand.primary,
                    size: isBestValue ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayAmountWithBonus,
                        style: TextStyle(
                          fontSize: isBestValue ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pack.calculatedBonusDiamonds > 0
                            ? '${pack.title.isNotEmpty ? pack.title : "${pack.amount} Pack"} (${pack.totalDiamonds} Total 💎)'
                            : (pack.title.isNotEmpty ? pack.title : '${pack.amount} 💎 Pack'),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _AnimatedPressButton(
                  onTap: isBuying ? null : () => _handleBuyPack(pack, settings),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isBestValue ? 20 : 18,
                        vertical: isBestValue ? 11 : 10),
                    decoration: BoxDecoration(
                      color: isBestValue ? Colors.amber.shade500 : brand.primary,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isBestValue
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isBuying
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isBestValue ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(
                            priceText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isBestValue ? 15 : 14,
                              color: isBestValue ? Colors.black : Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required int cost,
    required int countOwned,
    required Color cardBg,
    required Color textColor,
    required FlavorConfig brand,
    required VoidCallback onBuy,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Owned: $countOwned',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _AnimatedPressButton(
              onTap: onBuy,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brand.primary.withValues(alpha: 0.15),
                      brand.secondary.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: brand.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.diamond_rounded,
                        color: brand.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$cost',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget providing micro-animated spring scale feedback on tap
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _AnimatedPressButton({
    required this.child,
    this.onTap,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
