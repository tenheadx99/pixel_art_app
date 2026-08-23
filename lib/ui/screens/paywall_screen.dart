import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_constants.dart';
import '../../config/flavor.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/iap_service.dart';
import '../../data/services/remote_config_service.dart';
import '../../providers/app_settings_provider.dart';
import '../theme/app_style.dart';
import '../widgets/entrance.dart';
import '../../l10n/app_localizations.dart';

/// Enhanced Paywall screen featuring subscription plans (Yearly, Monthly,
/// Weekly, 1-Day Pass) plus standalone Remove Ads and Lifetime Pro options.
class PaywallScreen extends StatefulWidget {
  final String source;

  const PaywallScreen({super.key, this.source = 'unknown'});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PageController _pageController;
  int _currentPageIndex = 0;
  String _selectedPlan = AppConstants.plusYearlyProductId;
  String? _oneDayPrice;
  String? _weeklyPrice;
  String? _monthlyPrice;
  String? _yearlyPrice;
  String? _removeAdsPrice;
  String? _lifetimePrice;
  AppSettingsProvider? _settings;
  bool _wasEntitled = false;
  late final DateTime _paywallOpenedAt;

  @override
  void initState() {
    super.initState();
    _paywallOpenedAt = DateTime.now();
    AnalyticsService().logPaywallShown(source: widget.source);
    _selectedPlan = RemoteConfigService().plusYearlyProductId;
    _pageController = PageController(viewportFraction: 0.84, initialPage: 0);
    _loadPrices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings == null) {
      _settings = context.read<AppSettingsProvider>();
      _wasEntitled = _settings!.isProUser;
      _settings!.addListener(_onSettingsChanged);
    }
  }

  Future<void> _loadPrices() async {
    final iap = context.read<IAPService>();
    final rc = RemoteConfigService();
    final p1day = await iap.getPrice(rc.plus1DayProductId);
    final pWeekly = await iap.getPrice(rc.plusWeeklyProductId);
    final pMonthly = await iap.getPrice(rc.plusMonthlyProductId);
    final pYearly = await iap.getPrice(rc.plusYearlyProductId);
    final pRemoveAds = await iap.getPrice(rc.removeAdsProductId);
    final lifetime = await iap.getPrice(AppConstants.proProductId);
    if (!mounted) return;
    setState(() {
      _oneDayPrice = p1day ?? rc.plus1DayFallbackPrice;
      _weeklyPrice = pWeekly ?? rc.plusWeeklyFallbackPrice;
      _monthlyPrice = pMonthly ?? rc.plusMonthlyFallbackPrice;
      _yearlyPrice = pYearly ?? rc.plusYearlyFallbackPrice;
      _removeAdsPrice = pRemoveAds ?? rc.removeAdsFallbackPrice;
      _lifetimePrice = lifetime ?? rc.lifetimeProFallbackPrice;
    });
  }

  void _onSettingsChanged() {
    if (!_wasEntitled && (_settings?.isProUser ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Only log dismissed if the user did NOT purchase (settings would have popped)
    if (!(_settings?.isProUser ?? false)) {
      AnalyticsService().logPaywallDismissed(
        source: widget.source,
        timeOnScreenSeconds:
            DateTime.now().difference(_paywallOpenedAt).inSeconds,
      );
    }
    _pageController.dispose();
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _getButtonText(RemoteConfigService rc) {
    if (_selectedPlan == rc.removeAdsProductId) {
      return 'Remove Ads Now · ${_removeAdsPrice ?? rc.removeAdsFallbackPrice} 🚫';
    }
    if (_selectedPlan == rc.plusWeeklyProductId) {
      return 'Start 7 Days Free Trial 🎁';
    }
    if (_selectedPlan == rc.plusYearlyProductId) {
      return 'Get Yearly Pass (Save 65%) ✨';
    }
    if (_selectedPlan == rc.plusMonthlyProductId) {
      return 'Get Monthly Pass 👑';
    }
    if (_selectedPlan == rc.plus1DayProductId) {
      return 'Get 24-Hour Pass ⚡';
    }
    return 'Continue ✨';
  }

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;

    final rc = RemoteConfigService();
    final id1Day = rc.plus1DayProductId;
    final idWeekly = rc.plusWeeklyProductId;
    final idMonthly = rc.plusMonthlyProductId;
    final idYearly = rc.plusYearlyProductId;
    final idRemoveAds = rc.removeAdsProductId;

    final plans = [
      _PlanData(
        id: idYearly,
        title: 'Yearly VIP',
        badge: rc.plusYearlyOfferText,
        price: _yearlyPrice ?? rc.plusYearlyFallbackPrice,
        perks: [
          '💎 1,000 Bonus Diamonds',
          '🪄 Unlimited Wands & 💣 Bombs',
          '🛡️ 1 Free Monthly Streak Freeze',
          '🚫 Unlimited Access & No Ads',
        ],
        isBestValue: true,
      ),
      _PlanData(
        id: idWeekly,
        title: 'Weekly VIP',
        badge: rc.plusWeeklyOfferText,
        price: _weeklyPrice ?? rc.plusWeeklyFallbackPrice,
        perks: [
          '💎 100 Bonus Diamonds',
          '🪄 5 Daily Wands & 💣 5 Daily Bombs',
          '🎁 7-Day Free Trial · Cancel Anytime',
        ],
      ),
      _PlanData(
        id: idMonthly,
        title: 'Monthly VIP',
        badge: rc.plusMonthlyOfferText,
        price: _monthlyPrice ?? rc.plusMonthlyFallbackPrice,
        perks: [
          '💎 300 Bonus Diamonds',
          '🪄 10 Daily Wands & 💣 10 Daily Bombs',
          '🛡️ 1 Free Monthly Streak Freeze',
          '🚫 Unlimited Access & No Ads',
        ],
      ),
      _PlanData(
        id: id1Day,
        title: '24-Hour Pass',
        badge: rc.plus1DayOfferText,
        price: _oneDayPrice ?? rc.plus1DayFallbackPrice,
        perks: [
          '💎 25 Bonus Diamonds',
          '🪄 3 Free Wands & 💣 3 Free Bombs',
          '⚡ 24h Full Access & No Ads',
        ],
      ),
      _PlanData(
        id: idRemoveAds,
        title: 'Remove Ads Only',
        badge: rc.removeAdsOfferText,
        price: _removeAdsPrice ?? rc.removeAdsFallbackPrice,
        perks: [
          '🚫 Permanent Ad-Free Experience',
          '⚡ One-Time Purchase · No Subscription',
        ],
        isNoAds: true,
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1B1830), const Color(0xFF0F0D1B)]
                : [Colors.white, const Color(0xFFF0EBFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: subColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      // Shimmering crown badge
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: flavor.brandGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppStyle.primary.withAlpha(140),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${flavor.appName} VIP Pass',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock everything. Unlimited power-ups & no ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: subColor),
                      ),
                      const SizedBox(height: 16),

                      // Global perks summary
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            StaggeredEntrance(
                              slot: 0,
                              child: _PerkRow(
                                icon: Icons.palette_rounded,
                                title: 'All Premium Artworks Unlocked',
                                subtitle: 'Full access to entire catalog & new weekly packs',
                                color: titleColor,
                                subColor: subColor,
                              ),
                            ),
                            StaggeredEntrance(
                              slot: 1,
                              child: _PerkRow(
                                icon: Icons.block_rounded,
                                title: 'Zero Ads Guaranteed',
                                subtitle: 'No banners, interstitials, or popups',
                                color: titleColor,
                                subColor: subColor,
                              ),
                            ),
                            StaggeredEntrance(
                              slot: 2,
                              child: _PerkRow(
                                icon: Icons.diamond_rounded,
                                title: 'Bonus Diamonds & Power-ups',
                                subtitle: 'Daily wands, bombs & free diamonds',
                                color: titleColor,
                                subColor: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Horizontal PageView Carousel for Plans
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: plans.length,
                          onPageChanged: (index) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _currentPageIndex = index;
                              _selectedPlan = plans[index].id;
                            });
                          },
                          itemBuilder: (context, index) {
                            final plan = plans[index];
                            final isSelected = index == _currentPageIndex;
                            return AnimatedScale(
                              scale: isSelected ? 1.0 : 0.92,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedOpacity(
                                opacity: isSelected ? 1.0 : 0.75,
                                duration: const Duration(milliseconds: 200),
                                child: _CarouselPlanCard(
                                  plan: plan,
                                  selected: isSelected,
                                  onTap: () {
                                    _pageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Animated Page Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(plans.length, (i) {
                          final active = i == _currentPageIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppStyle.primary
                                    : subColor.withAlpha(60),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: AppStyle.primary.withAlpha(120),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // Call to Action Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              AnalyticsService().logPaywallCtaTapped(
                                source: widget.source,
                                productId: _selectedPlan,
                              );
                              context
                                  .read<IAPService>()
                                  .buySubscription(_selectedPlan);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyle.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 6,
                              shadowColor: AppStyle.primary.withAlpha(140),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              _getButtonText(rc),
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Lifetime Pro fallback link
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          AnalyticsService().logPaywallCtaTapped(
                            source: widget.source,
                            productId: AppConstants.proProductId,
                            plan: 'lifetime',
                          );
                          context.read<IAPService>().buyPro();
                        },
                        child: Text(
                          _lifetimePrice == null
                              ? 'Or unlock Lifetime Pro once'
                              : 'Or unlock Lifetime Pro once · $_lifetimePrice',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      Text(
                        'Cancel anytime in Google Play Store settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              AnalyticsService().logRestoreTapped();
                              context
                                  .read<IAPService>()
                                  .restorePurchases();
                            },
                            child: Text(
                              AppLocalizations.of(context)?.restorePurchases ?? 'Restore',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () => _openUrl(AppConstants.termsUrl),
                            child: Text(
                              AppLocalizations.of(context)?.termsOfService ?? 'Terms',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () => _openUrl(AppConstants.privacyPolicyUrl),
                            child: Text(
                              AppLocalizations.of(context)?.privacyPolicy ?? 'Privacy',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanData {
  final String id;
  final String title;
  final String? badge;
  final String price;
  final List<String> perks;
  final bool isBestValue;
  final bool isNoAds;

  const _PlanData({
    required this.id,
    required this.title,
    this.badge,
    required this.price,
    required this.perks,
    this.isBestValue = false,
    this.isNoAds = false,
  });
}

class _PerkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color subColor;

  const _PerkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppStyle.primary.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppStyle.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselPlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool selected;
  final VoidCallback onTap;

  const _CarouselPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;

    final cardBg = selected
        ? (isDark
            ? AppStyle.primary.withAlpha(50)
            : AppStyle.primary.withAlpha(22))
        : Theme.of(context).cardColor;

    final borderColor = selected
        ? (plan.isBestValue ? const Color(0xFFFF9D2E) : AppStyle.primary)
        : (isDark ? Colors.white12 : Colors.black12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: borderColor,
            width: selected ? 2.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: (plan.isBestValue ? const Color(0xFFFF9D2E) : AppStyle.primary)
                        .withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: titleColor,
                  ),
                ),
                if (plan.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: plan.isBestValue
                          ? const LinearGradient(
                              colors: [Color(0xFFFF9D2E), Color(0xFFFF6D00)],
                            )
                          : plan.isNoAds
                              ? const LinearGradient(
                                  colors: [Color(0xFF00B894), Color(0xFF0984E3)],
                                )
                              : null,
                      color: (!plan.isBestValue && !plan.isNoAds)
                          ? AppStyle.primary
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      plan.badge!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              plan.price,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: plan.isBestValue ? const Color(0xFFFF9D2E) : AppStyle.primary,
              ),
            ),
            Divider(height: 1, color: subColor.withAlpha(30)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final perk in plan.perks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Color(0xFF00B894),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            perk,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

