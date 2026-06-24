import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show kDebugMode;
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
    // AdMob/GDPR: gather consent via the UMP SDK before initializing ads, so
    // EEA/UK users see the consent form before any ad request is made.
    await _gatherConsent();
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  /// Runs the Google UMP consent flow. Requests an info update, then loads and
  /// shows the consent form if one is required (manual flow — google_mobile_ads
  /// 4.x has no one-shot helper). Fail-open: if the update/form errors we still
  /// proceed (the SDK serves limited/non-personalized ads where allowed). In
  /// debug builds it forces EEA geography so the form can be exercised.
  Future<void> _gatherConsent() async {
    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              // Add your test device's UMP id here while testing the form.
              testIdentifiers: const [],
            )
          : null,
    );
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final status = await ConsentInformation.instance.getConsentStatus();
          final available =
              await ConsentInformation.instance.isConsentFormAvailable();
          if (status == ConsentStatus.required && available) {
            await _loadAndShowConsentForm();
          }
        } catch (e) {
          developer.log('UMP consent handling failed', name: 'Ads', error: e);
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        developer.log(
          'UMP consent info update failed: ${error.message}',
          name: 'Ads',
        );
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  Future<void> _loadAndShowConsentForm() {
    final formCompleter = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm form) {
        form.show((FormError? error) {
          if (error != null) {
            developer.log('UMP form show error: ${error.message}', name: 'Ads');
          }
          if (!formCompleter.isCompleted) formCompleter.complete();
        });
      },
      (FormError error) {
        developer.log('UMP form load error: ${error.message}', name: 'Ads');
        if (!formCompleter.isCompleted) formCompleter.complete();
      },
    );
    return formCompleter.future;
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
