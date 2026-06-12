import 'dart:ui' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  bool _showingAppOpen = false;

  DateTime? _lastInterstitialAt;
  DateTime? _lastRewardedAt;
  DateTime? _lastAppOpenAt;

  /// Set during bootstrap; no full-screen ads in a user's very first session.
  bool isFirstSession = false;

  bool get _adsEnabled => !AppConfig.disableAds && AppConfig.showAds;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_adsEnabled) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // --- Interstitial (session-exit, frequency capped) ---

  void loadInterstitialAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (!_adsEnabled) {
      onFailed?.call();
      return;
    }
    _interstitialAd?.dispose();
    InterstitialAd.load(
      adUnitId: RemoteConfigService().interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) => onFailed?.call(),
      ),
    );
  }

  /// Caps that keep the exit interstitial from feeling punishing: never in
  /// the first session, only after real coloring time, with a cooldown and
  /// never right on the heels of a rewarded ad. All tunable via RemoteConfig.
  bool canShowSessionInterstitial(Duration sessionLength) {
    if (!_adsEnabled || isFirstSession || _interstitialAd == null) {
      return false;
    }
    final rc = RemoteConfigService();
    if (sessionLength.inSeconds < rc.interstitialMinSessionSeconds) {
      return false;
    }
    final now = DateTime.now();
    if (_lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!).inSeconds <
            rc.interstitialCooldownSeconds) {
      return false;
    }
    if (_lastRewardedAt != null &&
        now.difference(_lastRewardedAt!).inSeconds < 60) {
      return false;
    }
    return true;
  }

  void showInterstitialAd() {
    final ad = _interstitialAd;
    _interstitialAd = null;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, error) => a.dispose(),
    );
    _lastInterstitialAt = DateTime.now();
    ad.show();
  }

  // --- Rewarded ---

  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (!_adsEnabled) {
      onFailed?.call();
      return;
    }
    _rewardedAd?.dispose();
    RewardedAd.load(
      adUnitId: RemoteConfigService().rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) => onFailed?.call(),
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
    _lastRewardedAt = DateTime.now();
    _rewardedAd?.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded();
      },
    );
    _rewardedAd = null;
  }

  // --- App open (on resume, heavily capped) ---

  void loadAppOpenAd() {
    if (!_adsEnabled || _appOpenAd != null) return;
    AppOpenAd.load(
      adUnitId: RemoteConfigService().appOpenAdUnitId,
      request: const AdRequest(),
      orientation: AppOpenAd.orientationPortrait,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  void showAppOpenAdIfAvailable({required bool isProUser}) {
    if (!_adsEnabled || isProUser || _showingAppOpen || isFirstSession) return;
    final now = DateTime.now();
    if (_lastAppOpenAt != null &&
        now.difference(_lastAppOpenAt!).inSeconds <
            RemoteConfigService().appOpenCooldownSeconds) {
      return;
    }
    final ad = _appOpenAd;
    if (ad == null) {
      loadAppOpenAd(); // be ready for the next resume
      return;
    }
    _appOpenAd = null;
    _showingAppOpen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showingAppOpen = false;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _showingAppOpen = false;
      },
    );
    _lastAppOpenAt = now;
    ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }
}
