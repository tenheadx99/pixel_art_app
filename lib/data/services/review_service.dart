import 'dart:developer' as developer;
import 'package:in_app_review/in_app_review.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';

/// Requests the Play in-app review dialog at high-satisfaction moments
/// (right after a completed artwork's celebration HUD). Local gating sits on
/// top of the Play quota: never before [_minCompletions] finished artworks,
/// and at most one request per [_minDaysBetweenRequests] days. The Play API
/// applies its own quota and may silently no-op, so this can be called
/// liberally from qualifying moments.
class ReviewService {
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;
  ReviewService._();

  static const String _lastRequestKey = 'review_last_request_ms';
  static const int _minCompletions = 2;
  static const int _minDaysBetweenRequests = 30;

  bool _requestedThisSession = false;

  /// Asks Play for the review flow if this moment qualifies.
  /// [completedCount] is the player's lifetime finished-artwork count.
  Future<void> maybeRequestReview({
    required LocalStorageService storage,
    required int completedCount,
  }) async {
    if (_requestedThisSession || completedCount < _minCompletions) return;

    final lastMs = storage.getInt(_lastRequestKey);
    final now = DateTime.now();
    if (lastMs > 0 &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)).inDays <
            _minDaysBetweenRequests) {
      return;
    }

    try {
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;
      _requestedThisSession = true;
      storage.setInt(_lastRequestKey, now.millisecondsSinceEpoch);
      await inAppReview.requestReview();
    } catch (e) {
      developer.log('In-app review request failed', name: 'Review', error: e);
    }
  }
}
