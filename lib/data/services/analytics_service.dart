import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Service to handle Firebase Analytics event logging and user property setup.
///
/// All event names and parameter names comply with Firebase Analytics limits:
/// - Event names: ≤ 40 chars, alphanumeric + underscore
/// - Parameter names: ≤ 40 chars
/// - Parameter values: ≤ 100 chars
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

  // ---------------------------------------------------------------------------
  // Artwork Lifecycle
  // ---------------------------------------------------------------------------

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
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkSelected: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the user enters the coloring screen (route push).
  Future<void> logArtworkEntered({
    required String artId,
    required String category,
    String? title,
    required String flavor,
    int existingProgressPct = 0,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_entered',
        parameters: {
          'art_id': artId,
          'category': category,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'flavor': flavor,
          'existing_progress_pct': existingProgressPct,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkEntered: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the user exits the coloring screen (back/complete/app_close).
  Future<void> logArtworkExited({
    required String artId,
    String? title,
    required int seconds,
    required int progressPct,
    required String exitReason, // 'back' | 'completed' | 'app_close'
    required String flavor,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_exited',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'seconds': seconds,
          'progress_pct': progressPct,
          'exit_reason': exitReason,
          'flavor': flavor,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkExited: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an artwork is 100% completed.
  Future<void> logArtworkCompleted({
    required String artId,
    required String category,
    String? title,
    String? flavor,
    int? durationSeconds,
    int? cellsFilled,
    int? colorCount,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_completed',
        parameters: {
          'art_id': artId,
          'category': category,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'flavor': ?flavor,
          'duration_seconds': ?durationSeconds,
          'cells_filled': ?cellsFilled,
          'color_count': ?colorCount,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkCompleted: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when a user clears/resets artwork progress.
  Future<void> logArtworkCleared({
    required String artId,
    String? title,
    required int progressPct,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_cleared',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'progress_pct': progressPct,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkCleared: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs the end of a coloring session (screen exit).
  Future<void> logSessionEnd({
    required String artId,
    String? title,
    required int seconds,
    required int progressPct,
    required bool completed,
    String? flavor,
    String exitReason = 'back',
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'coloring_session_end',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'seconds': seconds,
          'progress_pct': progressPct,
          'completed': completed ? 1 : 0,
          'flavor': ?flavor,
          'exit_reason': exitReason,
        },
      );
    } catch (e) {
      developer.log('Error logging logSessionEnd: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a finished-artwork share (png still or gif time-lapse).
  Future<void> logArtworkShared({
    required String artId,
    required String format,
    String? title,
    String? flavor,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'artwork_shared',
        parameters: {
          'art_id': artId,
          'format': format,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'flavor': ?flavor,
        },
      );
    } catch (e) {
      developer.log('Error logging logArtworkShared: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs a time-lapse replay view.
  Future<void> logReplayWatched({required String artId, String? title}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'replay_watched',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
        },
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
    String? title,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'milestone_claimed',
        parameters: {
          'art_id': artId,
          'percent': percent,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
        },
      );
    } catch (e) {
      developer.log('Error logging logMilestoneClaimed: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Booster / Tool Usage
  // ---------------------------------------------------------------------------

  /// Logs a booster consumption (bomb / magic_wand / brush / hint).
  /// Also fires a separate depletion event when the last one is spent.
  Future<void> logBoosterUsed({
    required String type, // 'bomb' | 'magic_wand' | 'brush' | 'hint'
    required int remaining,
    String? artId,
    int? extraData, // cells_filled for wand/bomb, brush_size for brush
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'booster_used',
        parameters: {
          'type': type,
          'remaining': remaining,
          'art_id': ?artId,
          'extra': ?extraData,
        },
      );
      if (remaining == 0) {
        await a.logEvent(
          name: 'booster_depleted',
          parameters: {
            'type': type,
            'art_id': ?artId,
          },
        );
      }
    } catch (e) {
      developer.log('Error logging logBoosterUsed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs undo action.
  Future<void> logUndoUsed({required String artId}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'undo_used',
        parameters: {'art_id': artId},
      );
    } catch (e) {
      developer.log('Error logging logUndoUsed: $e', name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Ad Lifecycle — Full Coverage
  // ---------------------------------------------------------------------------

  /// Logs when an ad load request begins.
  Future<void> logAdLoadStart({
    required String adFormat,
    required String placement,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_load_start',
        parameters: {'ad_format': adFormat, 'placement': placement},
      );
    } catch (e) {
      developer.log('Error logging logAdLoadStart: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an ad loads successfully.
  Future<void> logAdLoadSuccess({
    required String adFormat,
    required String placement,
    int? loadTimeMs,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_load_success',
        parameters: {
          'ad_format': adFormat,
          'placement': placement,
          'load_time_ms': ?loadTimeMs,
        },
      );
    } catch (e) {
      developer.log('Error logging logAdLoadSuccess: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an ad fails to load.
  Future<void> logAdLoadFailed({
    required String adFormat,
    required String placement,
    String? errorCode,
    String? errorMessage,
    int retryAttempt = 0,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_load_failed',
        parameters: {
          'ad_format': adFormat,
          'placement': placement,
          'error_code': ?errorCode,
          if (errorMessage != null)
            'error_message': errorMessage.length > 100
                ? errorMessage.substring(0, 100)
                : errorMessage,
          'retry_attempt': retryAttempt,
        },
      );
    } catch (e) {
      developer.log('Error logging logAdLoadFailed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an ad is successfully shown (impression).
  Future<void> logAdImpression({
    required String adFormat,
    required String placement,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_impression_custom',
        parameters: {'ad_format': adFormat, 'placement': placement},
      );
    } catch (e) {
      developer.log('Error logging logAdImpression: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when an ad fails to show after being loaded.
  Future<void> logAdShowFailed({
    required String adFormat,
    required String placement,
    String? errorCode,
    String? errorMessage,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_show_failed',
        parameters: {
          'ad_format': adFormat,
          'placement': placement,
          'error_code': ?errorCode,
          if (errorMessage != null)
            'error_message': errorMessage.length > 100
                ? errorMessage.substring(0, 100)
                : errorMessage,
        },
      );
    } catch (e) {
      developer.log('Error logging logAdShowFailed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when a user dismisses a full-screen ad.
  Future<void> logAdDismissed({
    required String adFormat,
    required String placement,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_dismissed',
        parameters: {'ad_format': adFormat, 'placement': placement},
      );
    } catch (e) {
      developer.log('Error logging logAdDismissed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the ad is unavailable at show time (no fill).
  Future<void> logAdUnavailable({
    required String adFormat,
    required String placement,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'ad_unavailable',
        parameters: {'ad_format': adFormat, 'placement': placement},
      );
    } catch (e) {
      developer.log('Error logging logAdUnavailable: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs that a rewarded ad's reward was actually earned (watched through).
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

  // ---------------------------------------------------------------------------
  // In-App Purchase
  // ---------------------------------------------------------------------------

  /// Logs a purchase attempt starting (store sheet about to open).
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

  /// Logs in-app purchase success.
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

  /// Logs when a purchase attempt fails or is cancelled.
  Future<void> logPurchaseFailed({
    required String productId,
    String reason = 'cancelled', // 'cancelled' | 'error' | 'not_allowed'
    String? errorCode,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'iap_purchase_failed',
        parameters: {
          'product_id': productId,
          'reason': reason,
          'error_code': ?errorCode,
        },
      );
    } catch (e) {
      developer.log('Error logging logPurchaseFailed: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs restore purchases button tapped.
  Future<void> logRestoreTapped() async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(name: 'iap_restore_tapped', parameters: {});
    } catch (e) {
      developer.log('Error logging logRestoreTapped: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs successful restore (active entitlements found).
  Future<void> logRestoreSuccess({required int productsRestored}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'iap_restore_success',
        parameters: {'products_restored': productsRestored},
      );
    } catch (e) {
      developer.log('Error logging logRestoreSuccess: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs failed restore.
  Future<void> logRestoreFailed({String? errorCode}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'iap_restore_failed',
        parameters: {
          'error_code': ?errorCode,
        },
      );
    } catch (e) {
      developer.log('Error logging logRestoreFailed: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Paywall
  // ---------------------------------------------------------------------------

  /// Logs the paywall becoming visible, keyed by what led the user there.
  Future<void> logPaywallShown({
    required String source,
    String? flavor,
    bool? isPro,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'paywall_shown',
        parameters: {
          'source': source,
          'flavor': ?flavor,
          if (isPro != null) 'is_pro': isPro ? 1 : 0,
        },
      );
    } catch (e) {
      developer.log('Error logging logPaywallShown: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the user taps a pricing/CTA button on the paywall.
  Future<void> logPaywallCtaTapped({
    required String source,
    required String productId,
    String? plan, // 'monthly' | 'yearly' | 'lifetime'
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'paywall_cta_tapped',
        parameters: {
          'source': source,
          'product_id': productId,
          'plan': ?plan,
        },
      );
    } catch (e) {
      developer.log('Error logging logPaywallCtaTapped: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the user dismisses the paywall without purchasing.
  Future<void> logPaywallDismissed({
    required String source,
    int timeOnScreenSeconds = 0,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'paywall_dismissed',
        parameters: {
          'source': source,
          'time_on_screen_s': timeOnScreenSeconds,
        },
      );
    } catch (e) {
      developer.log('Error logging logPaywallDismissed: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Listing / Navigation
  // ---------------------------------------------------------------------------

  /// Logs when the Daily Pixel banner is tapped.
  Future<void> logDailyPixelTapped({
    required String artId,
    String? title,
    required bool completedToday,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'daily_pixel_tapped',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'completed_today': completedToday ? 1 : 0,
        },
      );
    } catch (e) {
      developer.log('Error logging logDailyPixelTapped: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the "Jump back in" continue row is tapped.
  Future<void> logContinueRowTapped({
    required String artId,
    String? title,
    required int progressPct,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'continue_row_tapped',
        parameters: {
          'art_id': artId,
          if (title != null) 'art_title': title.length > 100 ? title.substring(0, 100) : title,
          'progress_pct': progressPct,
        },
      );
    } catch (e) {
      developer.log('Error logging logContinueRowTapped: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when a gallery filter (category or favorites) is applied.
  Future<void> logGalleryFilterApplied({
    required String filterType, // 'category' | 'favorites'
    required String value,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'gallery_filter_applied',
        parameters: {
          'filter_type': filterType,
          'value': value,
        },
      );
    } catch (e) {
      developer.log('Error logging logGalleryFilterApplied: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Streak / Daily
  // ---------------------------------------------------------------------------

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

  /// Logs when a streak is lost.
  Future<void> logStreakBroken({required int brokenStreakValue}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'streak_broken',
        parameters: {'broken_streak_value': brokenStreakValue},
      );
    } catch (e) {
      developer.log('Error logging logStreakBroken: $e',
          name: 'AnalyticsService');
    }
  }

  /// Logs when the streak repair CTA is tapped.
  Future<void> logStreakRepaired({required int repairedValue}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'streak_repaired',
        parameters: {'repaired_value': repairedValue},
      );
    } catch (e) {
      developer.log('Error logging logStreakRepaired: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Camera / Photo
  // ---------------------------------------------------------------------------

  /// Logs when a user converts a custom photo into a pixel art canvas.
  Future<void> logPhotoConverted({
    required String source,
    String result = 'success', // 'success' | 'failed'
    int? imageSizePx,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'photo_converted',
        parameters: {
          'source': source,
          'result': result,
          'image_size_px': ?imageSizePx,
        },
      );
    } catch (e) {
      developer.log('Error logging logPhotoConverted: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // Force Update
  // ---------------------------------------------------------------------------

  /// Logs when the Force Update screen is shown to a user.
  Future<void> logForceUpdateShown({required String minVersion}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(
        name: 'force_update_shown',
        parameters: {'min_version': minVersion},
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
        parameters: {'update_url': updateUrl},
      );
    } catch (e) {
      developer.log('Error logging logForceUpdateClicked: $e',
          name: 'AnalyticsService');
    }
  }

  // ---------------------------------------------------------------------------
  // User Properties
  // ---------------------------------------------------------------------------

  /// Sets audience-segmentation user properties.
  Future<void> setPlayerProperties({
    int? level,
    bool? isPro,
    int? streakLength,
    int? totalCompleted,
    String? preferredCategory,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      if (level != null) {
        await a.setUserProperty(name: 'player_level', value: '$level');
      }
      if (isPro != null) {
        await a.setUserProperty(
            name: 'is_pro', value: isPro ? 'true' : 'false');
      }
      if (streakLength != null) {
        await a.setUserProperty(
            name: 'streak_length', value: '$streakLength');
      }
      if (totalCompleted != null) {
        await a.setUserProperty(
            name: 'total_completed', value: '$totalCompleted');
      }
      if (preferredCategory != null) {
        await a.setUserProperty(
            name: 'preferred_category', value: preferredCategory);
      }
    } catch (e) {
      developer.log('Error setting player properties: $e',
          name: 'AnalyticsService');
    }
  }
}
