import 'package:flutter/material.dart';
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

/// The Plus subscription paywall: monthly/yearly plans plus the existing
/// lifetime Pro as a one-time alternative. Purchases resolve through the IAP
/// purchase stream (AppSettingsProvider.listenToIAP); this screen just starts
/// the billing flow and pops itself once the entitlement lands.
class PaywallScreen extends StatefulWidget {
  /// What led the user here (e.g. 'home', 'settings') — logged with
  /// paywall_shown so conversion can be attributed per entry point.
  final String source;

  const PaywallScreen({super.key, this.source = 'unknown'});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selectedPlan = AppConstants.plusYearlyProductId;
  String? _oneDayPrice;
  String? _weeklyPrice;
  String? _monthlyPrice;
  String? _yearlyPrice;
  String? _lifetimePrice;
  AppSettingsProvider? _settings;
  bool _wasEntitled = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logPaywallShown(source: widget.source);
    _selectedPlan = RemoteConfigService().plusYearlyProductId;
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
    final lifetime = await iap.getPrice(AppConstants.proProductId);
    if (!mounted) return;
    setState(() {
      _oneDayPrice = p1day ?? rc.plus1DayFallbackPrice;
      _weeklyPrice = pWeekly ?? rc.plusWeeklyFallbackPrice;
      _monthlyPrice = pMonthly ?? rc.plusMonthlyFallbackPrice;
      _yearlyPrice = pYearly ?? rc.plusYearlyFallbackPrice;
      _lifetimePrice = lifetime ?? rc.lifetimeProFallbackPrice;
    });
  }

  /// Pops the paywall as soon as the purchase stream grants the entitlement.
  void _onSettingsChanged() {
    if (!_wasEntitled && (_settings?.isProUser ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1B1830), const Color(0xFF120F22)]
                : [Colors.white, const Color(0xFFF3F0FF)],
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: flavor.brandGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppStyle.primary.withAlpha(120),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${flavor.appName} Plus',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Color everything. No interruptions.',
                        style: TextStyle(fontSize: 14, color: subColor),
                      ),
                      const SizedBox(height: 20),
                      // Benefits slide in one after another
                      StaggeredEntrance(
                        slot: 0,
                        stepMs: 60,
                        child: _Benefit(
                          icon: Icons.palette_outlined,
                          text: 'Every premium artwork unlocked',
                          color: titleColor,
                        ),
                      ),
                      StaggeredEntrance(
                        slot: 1,
                        stepMs: 60,
                        child: _Benefit(
                          icon: Icons.block,
                          text: 'All ads removed',
                          color: titleColor,
                        ),
                      ),
                      StaggeredEntrance(
                        slot: 2,
                        stepMs: 60,
                        child: _Benefit(
                          icon: Icons.diamond_rounded,
                          text:
                              '+${AppConstants.diamondsDailyPlusStipend} diamonds every day',
                          color: titleColor,
                        ),
                      ),
                      StaggeredEntrance(
                        slot: 3,
                        stepMs: 60,
                        child: _Benefit(
                          icon: Icons.favorite_outline,
                          text: 'Support new artwork packs',
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 4 Subscription & Pass Plans
                      _PlanCard(
                        title: 'Yearly',
                        badge: rc.plusYearlyOfferText,
                        price: _yearlyPrice ?? rc.plusYearlyFallbackPrice,
                        fallbackPeriod: rc.plusYearlyFallbackPrice,
                        selected: _selectedPlan == idYearly,
                        onTap: () => setState(() => _selectedPlan = idYearly),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        title: 'Monthly',
                        badge: rc.plusMonthlyOfferText,
                        price: _monthlyPrice ?? rc.plusMonthlyFallbackPrice,
                        fallbackPeriod: rc.plusMonthlyFallbackPrice,
                        selected: _selectedPlan == idMonthly,
                        onTap: () => setState(() => _selectedPlan = idMonthly),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        title: 'Weekly',
                        badge: rc.plusWeeklyOfferText,
                        price: _weeklyPrice ?? rc.plusWeeklyFallbackPrice,
                        fallbackPeriod: rc.plusWeeklyFallbackPrice,
                        selected: _selectedPlan == idWeekly,
                        onTap: () => setState(() => _selectedPlan = idWeekly),
                      ),
                      const SizedBox(height: 10),
                      _PlanCard(
                        title: '1-Day Pass',
                        badge: rc.plus1DayOfferText,
                        price: _oneDayPrice ?? rc.plus1DayFallbackPrice,
                        fallbackPeriod: rc.plus1DayFallbackPrice,
                        selected: _selectedPlan == id1Day,
                        onTap: () => setState(() => _selectedPlan = id1Day),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context
                              .read<IAPService>()
                              .buySubscription(_selectedPlan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyle.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Continue ✨',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.read<IAPService>().buyPro(),
                        child: Text(
                          _lifetimePrice == null
                              ? 'Or buy Lifetime Pro once'
                              : 'Or buy Lifetime Pro once · $_lifetimePrice',
                          style: TextStyle(color: subColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subscription renews automatically until cancelled in '
                        'the Play Store. Cancel anytime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => context
                                .read<IAPService>()
                                .restorePurchases(),
                            child: Text(
                              AppLocalizations.of(context)?.restorePurchases ?? 'Restore',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _openUrl(AppConstants.termsUrl),
                            child: Text(
                              AppLocalizations.of(context)?.termsOfService ?? 'Terms',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _openUrl(AppConstants.privacyPolicyUrl),
                            child: Text(
                              AppLocalizations.of(context)?.privacyPolicy ?? 'Privacy',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Benefit({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppStyle.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String? price;
  final String fallbackPeriod;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    this.badge,
    required this.price,
    required this.fallbackPeriod,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
    final subColor = isDark ? Colors.white70 : Colors.black54;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppStyle.primary
                : AppStyle.primary.withAlpha(40),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppStyle.primary : subColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9D2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              price ?? fallbackPeriod,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
