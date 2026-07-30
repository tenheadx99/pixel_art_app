import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Service to handle Firebase Analytics event logging and user property setup.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analyticsInstance;
  FirebaseAnalytics? get _analytics {
    try {
      return _analyticsInstance ??= FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns navigator observer for automatic screen view tracking in MaterialApp.
  NavigatorObserver get observer {
    final a = _analytics;
    if (a == null) return NavigatorObserver();
    return FirebaseAnalyticsObserver(analytics: a);
  }

  /// Initializes analytics for the active app session and sets user properties.
  Future<void> init({required String flavorName}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserProperty(name: 'flavor', value: flavorName);
      await a.logAppOpen();
      developer.log('AnalyticsService initialized for flavor: $flavorName',
          name: 'AnalyticsService');
    } catch (e, st) {
      developer.log('Error initializing AnalyticsService: $e',
          name: 'AnalyticsService', error: e, stackTrace: st);
    }
  }

  /// Logs when an artwork canvas is selected / started by the user.
  Future<void> logArtworkSelected({
    required String artId,
    required String category,
    String? title,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logSelectContent(
        contentType: 'artwork',
        itemId: artId,
      );
      await a.logEvent(
        name: 'artwork_started',
        parameters: {
          'art_id': artId,
          'category': category,
          'title': ?title,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkSelected: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an artwork is 100% completed.
  Future<void> logArtworkCompleted({
    required String artId,
    required String category,
    int? durationSeconds,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_completed',
        parameters: {
          'art_id': artId,
          'category': category,
          'duration_seconds': ?durationSeconds,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkCompleted: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when a user converts a custom photo into a pixel art canvas.
  Future<void> logPhotoConverted({required String source}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'photo_converted',
        parameters: {
          'source': source,
        },
      );
    } catch (e) {
      developer.log('Error logging logPhotoConverted: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs ad events (rewarded, interstitial, banner).
  Future<void> logAdImpression({
    required String adFormat,
    required String placement,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_impression_custom',
        parameters: {
          'ad_format': adFormat,
          'placement': placement,
        },
      );
    } catch (e) {
      developer.log('Error logging logAdImpression: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs in-app purchase events.
  Future<void> logPurchase({
    required String productId,
    double? price,
    String? currency,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'iap_purchase_success',
        parameters: {
          'product_id': productId,
          'price': ?price,
          'currency': ?currency,
        },
      );
    } catch (e) {
      developer.log('Error logging logPurchase: $e', name: 'AnalyticsService');
    }
  }

  /// Logs the end of a coloring session (screen exit), the core
  /// retention/abandonment signal: how long, how far, finished or not.
  Future<void> logSessionEnd({
    required String artId,
    required int seconds,
    required int progressPct,
    required bool completed,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'coloring_session_end',
        parameters: {
          'art_id': artId,
          'seconds': seconds,
          'progress_pct': progressPct,
          'completed': completed ? 1 : 0,
        },
      );
    } catch (e) {
      developer.log('Error logging logSessionEnd: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a booster consumption (bomb / magic_wand / brush / hint) and, when
  /// the last one was just spent, a separate depletion event — the moment
  /// rewarded-ad and IAP willingness peaks.
  Future<void> logBoosterUsed({
    required String type,
    required int remaining,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'booster_used',
        parameters: {'type': type, 'remaining': remaining},
      );
      if (remaining == 0) {
        await a.logEvent(
          name: 'booster_depleted',
          parameters: {'type': type},
        );
      }
    } catch (e) {
      developer.log('Error logging logBoosterUsed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs that a rewarded ad's reward was actually earned (watched through),
  /// as opposed to merely shown.
  Future<void> logAdRewardEarned({required String placement}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_reward_earned',
        parameters: {'placement': placement},
      );
    } catch (e) {
      developer.log('Error logging logAdRewardEarned: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a finished-artwork share (png still or gif time-lapse).
  Future<void> logArtworkShared({
    required String artId,
    required String format,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_shared',
        parameters: {'art_id': artId, 'format': format},
      );
    } catch (e) {
      developer.log('Error logging logArtworkShared: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a time-lapse replay view.
  Future<void> logReplayWatched({required String artId}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'replay_watched',
        parameters: {'art_id': artId},
      );
    } catch (e) {
      developer.log('Error logging logReplayWatched: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a claimed progress milestone gift (30/65/100 percent).
  Future<void> logMilestoneClaimed({
    required String artId,
    required int percent,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'milestone_claimed',
        parameters: {'art_id': artId, 'percent': percent},
      );
    } catch (e) {
      developer.log('Error logging logMilestoneClaimed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs the paywall becoming visible, keyed by what led the user there.
  Future<void> logPaywallShown({required String source}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'paywall_shown',
        parameters: {'source': source},
      );
    } catch (e) {
      developer.log('Error logging logPaywallShown: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a purchase attempt starting (store sheet about to open), so
  /// conversion rate = iap_purchase_success / iap_purchase_start.
  Future<void> logPurchaseStart({required String productId}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'iap_purchase_start',
        parameters: {'product_id': productId},
      );
    } catch (e) {
      developer.log('Error logging logPurchaseStart: $e',
          name: 'AnalyticsService');
    }
  }

  /// Sets audience-segmentation user properties (call on load and whenever
  /// the values change).
  Future<void> setPlayerProperties({int? level, bool? isPro}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      if (level != null) {
        await a.setUserProperty(name: 'player_level', value: '$level');
      }
      if (isPro != null) {
        await a.setUserProperty(name: 'is_pro', value: isPro ? 'true' : 'false');
      }
    } catch (e) {
      developer.log('Error setting player properties: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs daily reward claims.
  Future<void> logDailyRewardClaimed({
    required int dayStreak,
    required int coins,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'daily_reward_claimed',
        parameters: {
          'streak': dayStreak,
          'coins': coins,
        },
      );
    } catch (e) {
      developer.log('Error logging logDailyRewardClaimed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the Force Update screen is shown to a user.
  Future<void> logForceUpdateShown({required String minVersion}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'force_update_shown',
        parameters: {
          'min_version': minVersion,
        },
      );
    } catch (e) {
      developer.log('Error logging logForceUpdateShown: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when a user clicks the "Update Now" button on the Force Update screen.
  Future<void> logForceUpdateClicked({required String updateUrl}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'force_update_clicked',
        parameters: {
          'update_url': updateUrl,
        },
      );
    } catch (e) {
      developer.log('Error logging logForceUpdateClicked: $e',
          name: 'AnalyticsService');
    }
  }
}

