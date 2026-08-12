import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';
import '../../config/flavor.dart';
import '../../data/services/remote_config_service.dart';

/// A full-width native ad styled to sit inside the home grid as a content
/// row. Uses the SDK's medium template (no per-platform NativeAdFactory
/// registration) tinted from the flavor's palette.
///
/// Reserves zero height until the ad actually loads (same contract as
/// AdBanner), so an unfilled slot costs no blank space. Each NativeAd is a
/// platform view: at most [_maxLive] are alive at once, and scroll-out
/// disposes the instance (the sliver tears the widget down), freeing its slot
/// for the next one scrolled in.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  static int _liveCount = 0;
  static const int _maxLive = 3;

  NativeAd? _ad;
  bool _loaded = false;

  // The medium template needs Theme colors, so load from
  // didChangeDependencies rather than initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  void _load() {
    if (AppConfig.disableAds || !AppConfig.showAds) return;
    final rc = RemoteConfigService();
    if (!rc.homeNativeAdsEnabled) return;
    final unitId = rc.nativeAdUnitId;
    if (unitId.isEmpty || _liveCount >= _maxLive) return;

    final theme = Theme.of(context);
    final primary = FlavorConfig.current.primary;
    _liveCount++;
    _ad = NativeAd(
      adUnitId: unitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: theme.cardColor,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: primary,
          size: 15,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodyLarge?.color,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.hintColor,
          size: 13,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // No retry loop: the next scroll-in builds a fresh state and tries
          // again, which is backoff enough for a feed slot.
          ad.dispose();
          _liveCount--;
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    if (_ad != null) {
      _ad!.dispose();
      _liveCount--;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        // The SDK's medium template wants >=320dp of height to lay out its
        // media view + headline + CTA without clipping.
        child: SizedBox(height: 320, child: AdWidget(ad: ad)),
      ),
    );
  }
}
