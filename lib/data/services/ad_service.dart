import 'dart:ui' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/app_constants.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  Future<void> initialize() async {
    if (_initialized) return;
    if (AppConfig.disableAds) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  BannerAd? get bannerAd => _bannerAd;

  void loadBannerAd() {
    if (AppConfig.disableAds) return;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {},
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  void loadInterstitialAd({VoidCallback? onLoaded}) {
    if (AppConfig.disableAds) return;
    _interstitialAd?.dispose();
    InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void showInterstitialAd() {
    _interstitialAd?.show();
    _interstitialAd = null;
  }

  void loadRewardedAd({VoidCallback? onLoaded}) {
    if (AppConfig.disableAds) return;
    _rewardedAd?.dispose();
    RewardedAd.load(
      adUnitId: AppConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void showRewardedAd({required void Function() onRewarded}) {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
      },
    );
    _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
      onRewarded();
    });
    _rewardedAd = null;
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
