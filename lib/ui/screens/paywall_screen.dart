import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_constants.dart';
import '../../config/flavor.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/economy_config_service.dart';
import '../../data/models/economy_config.dart';
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
  int _crownTapCount = 0;

  @override
  void initState() {
    super.initState();
    _paywallOpenedAt = DateTime.now();
    AnalyticsService().logPaywallShown(source: widget.source);
    final eco = EconomyConfigService().currentConfig.paywall;
    final rc = RemoteConfigService();
    if (eco.defaultPlan == 'monthly') {
      _selectedPlan = eco.plusMonthlyProductId.isNotEmpty ? eco.plusMonthlyProductId : rc.plusMonthlyProductId;
    } else if (eco.defaultPlan == 'weekly') {
      _selectedPlan = eco.plusWeeklyProductId.isNotEmpty ? eco.plusWeeklyProductId : rc.plusWeeklyProductId;
    } else if (eco.defaultPlan == '1day') {
      _selectedPlan = eco.plus1DayProductId.isNotEmpty ? eco.plus1DayProductId : rc.plus1DayProductId;
    } else if (eco.defaultPlan == 'remove_ads') {
      _selectedPlan = eco.removeAdsProductId.isNotEmpty ? eco.removeAdsProductId : rc.removeAdsProductId;
    } else {
      _selectedPlan = eco.plusYearlyProductId.isNotEmpty ? eco.plusYearlyProductId : rc.plusYearlyProductId;
    }
    _pageController = PageController(viewportFraction: 0.84, initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPrices();
    });
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
    if (!mounted) return;
    final iap = context.read<IAPService>();
    final rc = RemoteConfigService();
    final eco = EconomyConfigService().currentConfig.paywall;

    final id1Day = eco.plus1DayProductId.isNotEmpty ? eco.plus1DayProductId : rc.plus1DayProductId;
    final idWeekly = eco.plusWeeklyProductId.isNotEmpty ? eco.plusWeeklyProductId : rc.plusWeeklyProductId;
    final idMonthly = eco.plusMonthlyProductId.isNotEmpty ? eco.plusMonthlyProductId : rc.plusMonthlyProductId;
    final idYearly = eco.plusYearlyProductId.isNotEmpty ? eco.plusYearlyProductId : rc.plusYearlyProductId;
    final idRemoveAds = eco.removeAdsProductId.isNotEmpty ? eco.removeAdsProductId : rc.removeAdsProductId;
    final idLifetime = eco.lifetimeProductId.isNotEmpty ? eco.lifetimeProductId : AppConstants.proProductId;

    final p1day = await iap.getPrice(id1Day);
    final pWeekly = await iap.getPrice(idWeekly);
    final pMonthly = await iap.getPrice(idMonthly);
    final pYearly = await iap.getPrice(idYearly);
    final pRemoveAds = await iap.getPrice(idRemoveAds);
    final lifetime = await iap.getPrice(idLifetime);
    if (!mounted) return;
    setState(() {
      _oneDayPrice = p1day ?? (eco.plus1DayFallbackPrice.isNotEmpty ? eco.plus1DayFallbackPrice : rc.plus1DayFallbackPrice);
      _weeklyPrice = pWeekly ?? (eco.plusWeeklyFallbackPrice.isNotEmpty ? eco.plusWeeklyFallbackPrice : rc.plusWeeklyFallbackPrice);
      _monthlyPrice = pMonthly ?? (eco.plusMonthlyFallbackPrice.isNotEmpty ? eco.plusMonthlyFallbackPrice : rc.plusMonthlyFallbackPrice);
      _yearlyPrice = pYearly ?? (eco.plusYearlyFallbackPrice.isNotEmpty ? eco.plusYearlyFallbackPrice : rc.plusYearlyFallbackPrice);
      _removeAdsPrice = pRemoveAds ?? (eco.removeAdsFallbackPrice.isNotEmpty ? eco.removeAdsFallbackPrice : rc.removeAdsFallbackPrice);
      _lifetimePrice = lifetime ?? (eco.lifetimeFallbackPrice.isNotEmpty ? eco.lifetimeFallbackPrice : rc.lifetimeProFallbackPrice);
    });
  }


  void _showDiagnosticsSheet() {
    final flavor = FlavorConfig.current;
    final eco = EconomyConfigService().currentConfig.paywall;
    final rc = RemoteConfigService();
    final iap = context.read<IAPService>();
    final settings = context.read<AppSettingsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text('IAP & Paywall Diagnostics', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  Text('Flavor: ${flavor.appName} (${currentFlavor.name})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Store Connection: ${iap.isStoreAvailable ? "Connected ✅" : "Disconnected ⚠️"}'),
                  Text('Pro Status: ${settings.isProUser ? "ACTIVE 👑" : "Free User 🔒"}'),
                  Text('No Ads Status: ${settings.isRemoveAds ? "ACTIVE 🚫" : "Inactive"}'),
                  const SizedBox(height: 8),
                  const Text('Active Dynamic SKUs:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Yearly: ${eco.plusYearlyProductId.isNotEmpty ? eco.plusYearlyProductId : rc.plusYearlyProductId}'),
                  Text('• Monthly: ${eco.plusMonthlyProductId.isNotEmpty ? eco.plusMonthlyProductId : rc.plusMonthlyProductId}'),
                  Text('• Weekly: ${eco.plusWeeklyProductId.isNotEmpty ? eco.plusWeeklyProductId : rc.plusWeeklyProductId}'),
                  Text('• 1-Day: ${eco.plus1DayProductId.isNotEmpty ? eco.plus1DayProductId : rc.plus1DayProductId}'),
                  Text('• Remove Ads: ${eco.removeAdsProductId.isNotEmpty ? eco.removeAdsProductId : rc.removeAdsProductId}'),
                  Text('• Lifetime: ${eco.lifetimeProductId.isNotEmpty ? eco.lifetimeProductId : AppConstants.proProductId}'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Toggle VIP Entitlement'),
                        onPressed: () {
                          settings.setProUser(!settings.isProUser);
                          setSheetState(() {});
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Re-fetch Prices'),
                        onPressed: () {
                          _loadPrices();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isProcessing = false;

  Future<void> _handlePurchase(String productId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    AnalyticsService().logPaywallCtaTapped(
      source: widget.source,
      productId: productId,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Connecting to Google Play Store…'),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final launched =
        await context.read<IAPService>().buySubscription(productId);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final iapService = context.read<IAPService>();
      final isStoreAvailable = iapService.isStoreAvailable;
      final settings = context.read<AppSettingsProvider>();
      final rc = RemoteConfigService();
      final eco = EconomyConfigService().currentConfig.paywall;

      void activateTestEntitlement() {
        if (productId == eco.removeAdsProductId ||
            productId == rc.removeAdsProductId ||
            productId == AppConstants.removeAdsProductId) {
          settings.setRemoveAds(true);
        } else if (productId == eco.plus1DayProductId ||
            productId == rc.plus1DayProductId ||
            productId == AppConstants.plus1DayProductId) {
          settings.extendPlusEntitlement(AppConstants.plus1DayEntitlementDays);
        } else if (productId == eco.plusWeeklyProductId ||
            productId == rc.plusWeeklyProductId ||
            productId == AppConstants.plusWeeklyProductId) {
          settings.extendPlusEntitlement(AppConstants.plusWeeklyEntitlementDays);
        } else if (productId == eco.plusMonthlyProductId ||
            productId == rc.plusMonthlyProductId ||
            productId == AppConstants.plusMonthlyProductId) {
          settings.extendPlusEntitlement(AppConstants.plusMonthlyEntitlementDays);
        } else {
          settings.extendPlusEntitlement(AppConstants.plusYearlyEntitlementDays);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('VIP Pass Activated (Test Mode) 🎉'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (kDebugMode) {
        activateTestEntitlement();
      } else {
        final errorMsg = !isStoreAvailable
            ? 'Play Store is currently unavailable. Please verify Play Store login and connection.'
            : 'Product ($productId) is not configured in Google Play Console yet for this app.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Activate Test',
              textColor: Colors.white,
              onPressed: activateTestEntitlement,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBuyPro() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();
    AnalyticsService().logPaywallCtaTapped(
      source: widget.source,
      productId: AppConstants.proProductId,
      plan: 'lifetime',
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Connecting to Google Play Store…'),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final launched = await context.read<IAPService>().buyPro();
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final iapService = context.read<IAPService>();
      final isStoreAvailable = iapService.isStoreAvailable;
      final settings = context.read<AppSettingsProvider>();

      void activateProTest() {
        settings.setProUser(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lifetime Pro Activated (Test Mode) 🎉'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (kDebugMode) {
        activateProTest();
      } else {
        final errorMsg = !isStoreAvailable
            ? 'Play Store is currently unavailable. Please verify Play Store login and connection.'
            : 'Product (${AppConstants.proProductId}) is not configured in Google Play Console yet for this app.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Activate Test',
              textColor: Colors.white,
              onPressed: activateProTest,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
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

  String _getButtonText(RemoteConfigService rc, PaywallConfig eco) {
    if (_isProcessing) {
      return 'Processing… ⏳';
    }
    final idRemoveAds = eco.removeAdsProductId.isNotEmpty ? eco.removeAdsProductId : rc.removeAdsProductId;
    final idWeekly = eco.plusWeeklyProductId.isNotEmpty ? eco.plusWeeklyProductId : rc.plusWeeklyProductId;
    final idYearly = eco.plusYearlyProductId.isNotEmpty ? eco.plusYearlyProductId : rc.plusYearlyProductId;
    final idMonthly = eco.plusMonthlyProductId.isNotEmpty ? eco.plusMonthlyProductId : rc.plusMonthlyProductId;
    final id1Day = eco.plus1DayProductId.isNotEmpty ? eco.plus1DayProductId : rc.plus1DayProductId;

    if (_selectedPlan == idRemoveAds) {
      final p = _removeAdsPrice ?? (eco.removeAdsFallbackPrice.isNotEmpty ? eco.removeAdsFallbackPrice : rc.removeAdsFallbackPrice);
      return 'Remove Ads Now · $p 🚫';
    }
    if (_selectedPlan == idWeekly) {
      return 'Start 7 Days Free Trial 🎁';
    }
    if (_selectedPlan == idYearly) {
      return 'Get Yearly Pass (Save 65%) ✨';
    }
    if (_selectedPlan == idMonthly) {
      return 'Get Monthly Pass 👑';
    }
    if (_selectedPlan == id1Day) {
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
    final eco = EconomyConfigService().currentConfig.paywall;

    final id1Day = eco.plus1DayProductId.isNotEmpty ? eco.plus1DayProductId : rc.plus1DayProductId;
    final idWeekly = eco.plusWeeklyProductId.isNotEmpty ? eco.plusWeeklyProductId : rc.plusWeeklyProductId;
    final idMonthly = eco.plusMonthlyProductId.isNotEmpty ? eco.plusMonthlyProductId : rc.plusMonthlyProductId;
    final idYearly = eco.plusYearlyProductId.isNotEmpty ? eco.plusYearlyProductId : rc.plusYearlyProductId;
    final idRemoveAds = eco.removeAdsProductId.isNotEmpty ? eco.removeAdsProductId : rc.removeAdsProductId;

    final badge1Day = eco.plus1DayOffer.isNotEmpty ? eco.plus1DayOffer : rc.plus1DayOfferText;
    final badgeWeekly = eco.plusWeeklyOffer.isNotEmpty ? eco.plusWeeklyOffer : rc.plusWeeklyOfferText;
    final badgeMonthly = eco.plusMonthlyOffer.isNotEmpty ? eco.plusMonthlyOffer : rc.plusMonthlyOfferText;
    final badgeYearly = eco.plusYearlyOffer.isNotEmpty ? eco.plusYearlyOffer : rc.plusYearlyOfferText;
    final badgeRemoveAds = eco.removeAdsOffer.isNotEmpty ? eco.removeAdsOffer : rc.removeAdsOfferText;

    final allPlans = [
      if (eco.showYearlyPlan)
        _PlanData(
          id: idYearly,
          title: 'Yearly VIP',
          badge: badgeYearly,
          price: _yearlyPrice ?? (eco.plusYearlyFallbackPrice.isNotEmpty ? eco.plusYearlyFallbackPrice : rc.plusYearlyFallbackPrice),
          perks: [
            '💎 1,000 Bonus Diamonds',
            '🪄 Unlimited Wands & 💣 Bombs',
            '🛡️ 1 Free Monthly Streak Freeze',
            '🚫 Unlimited Access & No Ads',
          ],
          isBestValue: true,
        ),
      if (eco.showWeeklyPlan)
        _PlanData(
          id: idWeekly,
          title: 'Weekly VIP',
          badge: badgeWeekly,
          price: _weeklyPrice ?? (eco.plusWeeklyFallbackPrice.isNotEmpty ? eco.plusWeeklyFallbackPrice : rc.plusWeeklyFallbackPrice),
          perks: [
            '💎 100 Bonus Diamonds',
            '🪄 5 Daily Wands & 💣 5 Daily Bombs',
            '🎁 7-Day Free Trial · Cancel Anytime',
          ],
        ),
      if (eco.showMonthlyPlan)
        _PlanData(
          id: idMonthly,
          title: 'Monthly VIP',
          badge: badgeMonthly,
          price: _monthlyPrice ?? (eco.plusMonthlyFallbackPrice.isNotEmpty ? eco.plusMonthlyFallbackPrice : rc.plusMonthlyFallbackPrice),
          perks: [
            '💎 300 Bonus Diamonds',
            '🪄 10 Daily Wands & 💣 10 Daily Bombs',
            '🛡️ 1 Free Monthly Streak Freeze',
            '🚫 Unlimited Access & No Ads',
          ],
        ),
      if (eco.show1DayPlan)
        _PlanData(
          id: id1Day,
          title: '24-Hour Pass',
          badge: badge1Day,
          price: _oneDayPrice ?? (eco.plus1DayFallbackPrice.isNotEmpty ? eco.plus1DayFallbackPrice : rc.plus1DayFallbackPrice),
          perks: [
            '💎 25 Bonus Diamonds',
            '🪄 3 Free Wands & 💣 3 Free Bombs',
            '⚡ 24h Full Access & No Ads',
          ],
        ),
      if (eco.showRemoveAdsPlan)
        _PlanData(
          id: idRemoveAds,
          title: 'Remove Ads Only',
          badge: badgeRemoveAds,
          price: _removeAdsPrice ?? (eco.removeAdsFallbackPrice.isNotEmpty ? eco.removeAdsFallbackPrice : rc.removeAdsFallbackPrice),
          perks: [
            '🚫 Permanent Ad-Free Experience',
            '⚡ One-Time Purchase · No Subscription',
          ],
          isNoAds: true,
        ),
    ];
    final plans = allPlans.isNotEmpty ? allPlans : [
      _PlanData(
        id: idYearly,
        title: 'Yearly VIP',
        badge: badgeYearly,
        price: _yearlyPrice ?? rc.plusYearlyFallbackPrice,
        perks: ['💎 1,000 Bonus Diamonds', '🚫 Unlimited Access & No Ads'],
        isBestValue: true,
      ),
    ];

    // Ensure selected plan exists in active plans list
    if (!plans.any((p) => p.id == _selectedPlan)) {
      _selectedPlan = plans.first.id;
      _currentPageIndex = 0;
    } else {
      final idx = plans.indexWhere((p) => p.id == _selectedPlan);
      if (idx != -1 && idx != _currentPageIndex && !_pageController.hasClients) {
        _currentPageIndex = idx;
        _pageController = PageController(viewportFraction: 0.84, initialPage: idx);
      }
    }

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
                      GestureDetector(
                        onTap: () {
                          _crownTapCount++;
                          if (_crownTapCount >= 3) {
                            _crownTapCount = 0;
                            HapticFeedback.mediumImpact();
                            _showDiagnosticsSheet();
                          }
                        },
                        child: Container(
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withAlpha(isDark ? 35 : 25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFB300).withAlpha(100),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFFFB300),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4.8 Rating  •  Over 100,000+ Happy Artists',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFB300),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (eco.showUrgencyTimer) ...[
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withAlpha(80),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                '${eco.urgencyHeadline} • Ends Soon',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                                    if (isSelected) {
                                      // If already selected, tap immediately triggers purchase!
                                      _handlePurchase(plan.id);
                                    } else {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }
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
                            onPressed: _isProcessing
                                ? null
                                : () => _handlePurchase(_selectedPlan),
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
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _getButtonText(rc, eco),
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
                        onPressed: _isProcessing ? null : _handleBuyPro,
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

