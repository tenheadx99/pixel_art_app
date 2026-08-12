import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  AppOpenAd? _appOpenAd;
  bool _showingAppOpen = false;

  /// Backs the per-day interstitial cap; attached during bootstrap. Without
  /// it (tests) the per-day cap is simply skipped.
  LocalStorageService? _storage;
  void attachStorage(LocalStorageService storage) => _storage = storage;

  DateTime? _lastInterstitialAt;
  DateTime? _lastRewardedAt;
  DateTime? _lastAppOpenAt;

  // Failed loads retry at most this many times (20s, then 40s — same schedule
  // as AdBanner) and then stop until the next show/preload attempt re-arms
  // them, so a no-fill streak can't snowball into request spam.
  static const int _maxLoadRetries = 2;
  Duration _retryDelay(int attempt) => Duration(seconds: 20 * attempt);

  // Cached ads expire server-side (1h for interstitial/rewarded, 4h for
  // app-open). Showing an expired ad silently no-ops — a request with no
  // impression — so treat anything older than this as absent.
  static const Duration _fullScreenAdTtl = Duration(minutes: 50);
  static const Duration _appOpenAdTtl = Duration(hours: 3, minutes: 30);

  int _rewardedRetries = 0, _interstitialRetries = 0, _appOpenRetries = 0;
  int _rewardedInterstitialRetries = 0;
  DateTime? _rewardedLoadedAt, _interstitialLoadedAt, _appOpenLoadedAt;
  DateTime? _rewardedInterstitialLoadedAt;
  bool _rewardedLoading = false;

  /// Full-screen interruptions shown this app session (interstitial +
  /// rewarded interstitial — one shared pacing pool).
  int _interstitialsThisSession = 0;

  static const String _interstitialDayPrefKey = 'interstitial_day';
  static const String _interstitialDayCountPrefKey = 'interstitial_day_count';

  String get _todayStamp {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int get _interstitialsToday {
    final storage = _storage;
    if (storage == null) return 0;
    if (storage.getString(_interstitialDayPrefKey) != _todayStamp) return 0;
    return storage.getInt(_interstitialDayCountPrefKey);
  }

  void _countInterstitialShown() {
    _interstitialsThisSession++;
    final storage = _storage;
    if (storage == null) return;
    final count = _interstitialsToday + 1;
    storage.setString(_interstitialDayPrefKey, _todayStamp);
    storage.setInt(_interstitialDayCountPrefKey, count);
  }

  /// Set during bootstrap; no full-screen ads in a user's very first session.
  bool isFirstSession = false;

  bool get _adsEnabled => !AppConfig.disableAds && AppConfig.showAds;

  /// Interstitial + app-open only; banner/rewarded follow [_adsEnabled].
  bool get _fullScreenAdsEnabled =>
      _adsEnabled && !AppConfig.disableFullScreenAds;

  bool _isFresh(DateTime? loadedAt, Duration ttl) =>
      loadedAt != null && DateTime.now().difference(loadedAt) < ttl;

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
    if (!_fullScreenAdsEnabled) {
      onFailed?.call();
      return;
    }
    if (_interstitialAd != null &&
        _isFresh(_interstitialLoadedAt, _fullScreenAdTtl)) {
      onLoaded?.call();
      return;
    }
    _interstitialAd?.dispose();
    _interstitialAd = null;
    InterstitialAd.load(
      adUnitId: RemoteConfigService().interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadedAt = DateTime.now();
          _interstitialRetries = 0;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          developer.log('Interstitial load failed: ${error.message}',
              name: 'Ads');
          onFailed?.call();
          if (_interstitialRetries < _maxLoadRetries) {
            _interstitialRetries++;
            Future.delayed(
                _retryDelay(_interstitialRetries), loadInterstitialAd);
          }
        },
      ),
    );
  }

  /// Pacing shared by the exit interstitial and the "next artwork" rewarded
  /// interstitial (one interruption pool): never in the first session, only
  /// after real coloring time OR real progress, cooldown between shows,
  /// session/daily ceilings, never right on the heels of a rewarded ad. All
  /// tunable via RemoteConfig.
  bool _passesInterstitialPacing(Duration sessionLength, int progressPct) {
    if (!_fullScreenAdsEnabled || isFirstSession) return false;
    final rc = RemoteConfigService();
    // Short session AND little progress: a drive-by, leave them alone. A user
    // who coloured a quarter of a piece in 110s earned their exit ad slot.
    if (sessionLength.inSeconds < rc.interstitialMinSessionSeconds &&
        progressPct < rc.interstitialMinProgressPct) {
      return false;
    }
    // Ceilings: the cooldown alone lets a long session serve 20+.
    if (_interstitialsThisSession >= rc.interstitialMaxPerSession) return false;
    if (_storage != null && _interstitialsToday >= rc.interstitialMaxPerDay) {
      return false;
    }
    final now = DateTime.now();
    if (_lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!).inSeconds <
            rc.interstitialCooldownSeconds) {
      return false;
    }
    if (_lastRewardedAt != null &&
        now.difference(_lastRewardedAt!).inSeconds <
            rc.interstitialPostRewardedSeconds) {
      return false;
    }
    return true;
  }

  bool canShowSessionInterstitial(Duration sessionLength,
      {int progressPct = 0}) {
    return _interstitialAd != null &&
        _isFresh(_interstitialLoadedAt, _fullScreenAdTtl) &&
        _passesInterstitialPacing(sessionLength, progressPct);
  }

  void showInterstitialAd() {
    final ad = _interstitialAd;
    _interstitialAd = null;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        loadInterstitialAd();
      },
    );
    _lastInterstitialAt = DateTime.now();
    _countInterstitialShown();
    AnalyticsService().logAdImpression(adFormat: 'interstitial', placement: 'session_exit');
    ad.show();
  }

  // --- Rewarded interstitial ("next artwork": same interruption slot as the
  // exit interstitial, but opt-out and it pays the user) ---

  /// Disabled until a rewarded-interstitial unit id is configured in RC.
  bool get _rewardedInterstitialEnabled =>
      _fullScreenAdsEnabled &&
      RemoteConfigService().rewardedInterstitialAdUnitId.isNotEmpty;

  bool get isRewardedInterstitialReady =>
      _rewardedInterstitialAd != null &&
      _isFresh(_rewardedInterstitialLoadedAt, _fullScreenAdTtl);

  void preloadRewardedInterstitial() {
    if (!_rewardedInterstitialEnabled || isRewardedInterstitialReady) return;
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    RewardedInterstitialAd.load(
      adUnitId: RemoteConfigService().rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _rewardedInterstitialLoadedAt = DateTime.now();
          _rewardedInterstitialRetries = 0;
        },
        onAdFailedToLoad: (error) {
          developer.log('Rewarded interstitial load failed: ${error.message}',
              name: 'Ads');
          if (_rewardedInterstitialRetries < _maxLoadRetries) {
            _rewardedInterstitialRetries++;
            Future.delayed(_retryDelay(_rewardedInterstitialRetries),
                preloadRewardedInterstitial);
          }
        },
      ),
    );
  }

  /// Same pacing pool as [canShowSessionInterstitial], gated on a loaded
  /// rewarded interstitial instead of a plain one.
  bool canShowRewardedInterstitial(Duration sessionLength,
      {int progressPct = 0}) {
    return isRewardedInterstitialReady &&
        _passesInterstitialPacing(sessionLength, progressPct);
  }

  /// Shows the cached rewarded interstitial. Counts toward the interstitial
  /// session/day caps and cooldown — it occupies the same interruption slot.
  /// [onRewarded] fires only on the SDK's earned-reward callback (the user
  /// can opt out during the intro countdown).
  void showRewardedInterstitialAd({
    required VoidCallback onRewarded,
    String placement = 'next_art',
  }) {
    final ad = _rewardedInterstitialAd;
    _rewardedInterstitialAd = null;
    if (ad == null) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preloadRewardedInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        developer.log(
            'Rewarded interstitial show failed: ${error.message}',
            name: 'Ads');
        a.dispose();
        preloadRewardedInterstitial();
      },
    );
    _lastInterstitialAt = DateTime.now();
    _countInterstitialShown();
    AnalyticsService()
        .logAdImpression(adFormat: 'rewarded_interstitial', placement: placement);
    ad.show(
      onUserEarnedReward: (ad, reward) {
        AnalyticsService().logAdRewardEarned(placement: placement);
        onRewarded();
      },
    );
  }

  // --- Rewarded (cache-ahead: preloaded at startup, refilled after show) ---

  bool get isRewardedAdReady =>
      _rewardedAd != null && _isFresh(_rewardedLoadedAt, _fullScreenAdTtl);

  /// Fire-and-forget cache fill. Safe to call anytime; no-ops if a fresh ad
  /// is already cached or a load is in flight.
  void preloadRewardedAd() {
    if (!_adsEnabled || _rewardedLoading || isRewardedAdReady) return;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _rewardedLoading = true;
    developer.log('Rewarded load start', name: 'Ads');
    RewardedAd.load(
      adUnitId: RemoteConfigService().rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoadedAt = DateTime.now();
          _rewardedLoading = false;
          _rewardedRetries = 0;
          developer.log('Rewarded loaded', name: 'Ads');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          developer.log('Rewarded load failed: ${error.message}', name: 'Ads');
          if (_rewardedRetries < _maxLoadRetries) {
            _rewardedRetries++;
            Future.delayed(_retryDelay(_rewardedRetries), preloadRewardedAd);
          }
        },
      ),
    );
  }

  /// Shows the cached rewarded ad instantly. If a load is in flight (cold
  /// cache), waits up to ~5s for it — preserving the old tap-then-brief-wait
  /// UX as a worst case. When no ad can be shown, [onUnavailable] fires and a
  /// preload is re-armed for next time; the reward is NEVER granted without
  /// the SDK's earned-reward callback.
  Future<void> showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onUnavailable,
    String placement = 'user_reward',
  }) async {
    if (!_adsEnabled) {
      onUnavailable?.call();
      return;
    }
    if (!isRewardedAdReady) {
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _rewardedRetries = 0; // user intent re-arms a stopped retry cycle
      preloadRewardedAd();
      final waitUntil = DateTime.now().add(const Duration(seconds: 5));
      while (_rewardedLoading && DateTime.now().isBefore(waitUntil)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    final ad = _rewardedAd;
    if (ad == null || !_isFresh(_rewardedLoadedAt, _fullScreenAdTtl)) {
      onUnavailable?.call();
      return;
    }
    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        developer.log('Rewarded show failed: ${error.message}', name: 'Ads');
        a.dispose();
        preloadRewardedAd();
      },
    );
    _lastRewardedAt = DateTime.now();
    AnalyticsService().logAdImpression(adFormat: 'rewarded', placement: placement);
    ad.show(
      onUserEarnedReward: (ad, reward) {
        // Earned = watched through; distinct from the impression above so
        // completion rate per placement is measurable.
        AnalyticsService().logAdRewardEarned(placement: placement);
        onRewarded();
      },
    );
  }

  // --- App open (on resume, heavily capped) ---

  void loadAppOpenAd() {
    if (!_fullScreenAdsEnabled) return;
    if (_appOpenAd != null && _isFresh(_appOpenLoadedAt, _appOpenAdTtl)) {
      return;
    }
    _appOpenAd?.dispose();
    _appOpenAd = null;
    AppOpenAd.load(
      adUnitId: RemoteConfigService().appOpenAdUnitId,
      request: const AdRequest(),
      orientation: AppOpenAd.orientationPortrait,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
          _appOpenRetries = 0;
        },
        onAdFailedToLoad: (error) {
          developer.log('App-open load failed: ${error.message}', name: 'Ads');
          if (_appOpenRetries < _maxLoadRetries) {
            _appOpenRetries++;
            Future.delayed(_retryDelay(_appOpenRetries), loadAppOpenAd);
          }
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable({required bool isProUser}) {
    if (!_fullScreenAdsEnabled || isProUser || _showingAppOpen || isFirstSession) {
      return;
    }
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
    if (!_isFresh(_appOpenLoadedAt, _appOpenAdTtl)) {
      ad.dispose();
      _appOpenAd = null;
      loadAppOpenAd();
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
        loadAppOpenAd();
      },
    );
    _lastAppOpenAt = now;
    AnalyticsService().logAdImpression(adFormat: 'app_open', placement: 'resume');
    ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    _appOpenAd?.dispose();
  }
}
