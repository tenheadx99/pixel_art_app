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
}
