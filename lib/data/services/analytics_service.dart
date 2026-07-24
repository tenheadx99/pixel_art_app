import 'dart:developer' as developer;
import 'package:firebase_analytics/firebase_analytics.dart';

/// Service to handle Firebase Analytics event logging and user property setup.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Returns navigator observer for automatic screen view tracking in MaterialApp.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Initializes analytics for the active app session and sets user properties.
  Future<void> init({required String flavorName}) async {
    try {
      await _analytics.setUserProperty(name: 'flavor', value: flavorName);
      await _analytics.logAppOpen();
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
    try {
      await _analytics.logSelectContent(
        contentType: 'artwork',
        itemId: artId,
      );
      await _analytics.logEvent(
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
    try {
      await _analytics.logEvent(
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
    try {
      await _analytics.logEvent(
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
    try {
      await _analytics.logEvent(
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
    try {
      await _analytics.logEvent(
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

  /// Logs daily reward claims.
  Future<void> logDailyRewardClaimed({
    required int dayStreak,
    required int coins,
  }) async {
    try {
      await _analytics.logEvent(
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
}
