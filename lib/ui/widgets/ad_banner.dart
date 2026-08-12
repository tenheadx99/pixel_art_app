import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';
import '../../data/services/remote_config_service.dart';

/// Self-contained banner: owns its BannerAd instance (so multiple screens can
/// show banners simultaneously), reserves space only after the ad actually
/// loads, and retries on no-fill with backoff.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int _retries = 0;
  AnchoredAdaptiveBannerAdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_adSize == null) {
      _loadAdaptiveAdSize();
    }
  }

  Future<void> _loadAdaptiveAdSize() async {
    if (AppConfig.disableAds ||
        AppConfig.disableBannerAds ||
        !AppConfig.showAds) {
      return;
    }
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    setState(() {
      _adSize = size;
    });
    _load();
  }

  void _load() {
    final size = _adSize;
    if (size == null) return;
    final banner = BannerAd(
      adUnitId: RemoteConfigService().bannerAdUnitId,
      size: size,
      // Collapsible-bottom variant lifts banner eCPM where supported; plain
      // banner request when the RC flag is off.
      request: RemoteConfigService().bannerCollapsibleEnabled
          ? const AdRequest(extras: {'collapsible': 'bottom'})
          : const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          if (_retries < 2) {
            _retries++;
            Future.delayed(Duration(seconds: 20 * _retries), () {
              if (mounted) _load();
            });
          }
        },
      ),
    );
    _ad = banner;
    banner.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _adSize;
    if (!_loaded || ad == null || size == null) return const SizedBox.shrink();
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
