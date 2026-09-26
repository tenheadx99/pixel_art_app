import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';

/// Manages app rating and review flows.
/// - Once the user gives a rating, [hasRated] is stored so they are never prompted again.
/// - On artwork completion: shows rating dialog if [hasRated] is false.
/// - On artwork listing (Home): shows rating dialog if [hasRated] is false and user
///   has not dismissed it during the current app session. If dismissed, it re-prompts
///   on the next app launch.
class ReviewService {
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;
  ReviewService._();

  static const String _hasRatedKey = 'app_has_rated';
  static const String _lastRequestKey = 'review_last_request_ms';

  bool _dismissedOnHomeThisSession = false;

  @visibleForTesting
  bool get dismissedOnHomeThisSession => _dismissedOnHomeThisSession;

  @visibleForTesting
  void resetSessionForTesting() {
    _dismissedOnHomeThisSession = false;
  }

  /// Whether the user has already submitted a rating / review.
  bool hasRated(LocalStorageService storage) =>
      storage.getBool(_hasRatedKey, defaultValue: false);

  /// Whether the rating prompt should be shown on the home artwork listing screen.
  /// Shows if user completed at least 1 artwork, hasn't rated yet, and hasn't
  /// dismissed it in the current app session.
  bool shouldShowOnHome({
    required LocalStorageService storage,
    required int completedCount,
  }) {
    if (hasRated(storage)) return false;
    if (completedCount < 1) return false;
    if (_dismissedOnHomeThisSession) return false;
    return true;
  }

  /// Mark dismissed on Home for the current app session so it only reappears on next launch.
  void dismissOnHome() {
    _dismissedOnHomeThisSession = true;
  }

  /// Whether the rating prompt should be shown when an artwork is finished.
  /// Shows on every completion if the user has not yet rated.
  bool shouldShowOnCompletion({
    required LocalStorageService storage,
    required int completedCount,
  }) {
    if (hasRated(storage)) return false;
    if (completedCount < 1) return false;
    return true;
  }

  /// Marks that the user has rated and requests the native Play in-app review dialog.
  /// Does NOT redirect to Google Play or external store.
  Future<void> submitRating({
    required LocalStorageService storage,
    int stars = 5,
  }) async {
    storage.setBool(_hasRatedKey, true);
    storage.setInt(_lastRequestKey, DateTime.now().millisecondsSinceEpoch);

    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    } catch (e) {
      developer.log('Rating submission error', name: 'Review', error: e);
    }
  }

  /// Requests the native Play in-app review dialog directly without any external redirect.
  Future<void> requestInAppReview({
    required LocalStorageService storage,
    bool markRated = true,
  }) async {
    if (markRated) {
      storage.setBool(_hasRatedKey, true);
    }
    storage.setInt(_lastRequestKey, DateTime.now().millisecondsSinceEpoch);

    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    } catch (e) {
      developer.log('In-app review request failed', name: 'Review', error: e);
    }
  }

  /// Requests the native Play in-app review dialog directly.
  Future<void> maybeRequestReview({
    required LocalStorageService storage,
    required int completedCount,
  }) async {
    if (hasRated(storage) || completedCount < 1) return;

    try {
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;
      storage.setInt(_lastRequestKey, DateTime.now().millisecondsSinceEpoch);
      await inAppReview.requestReview();
    } catch (e) {
      developer.log('In-app review request failed', name: 'Review', error: e);
    }
  }

  /// Opens the store listing page directly (e.g. from Settings "Rate Us").
  Future<void> openStoreListing({String? appStoreId}) async {
    try {
      final inAppReview = InAppReview.instance;
      await inAppReview.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      developer.log('Open store listing failed', name: 'Review', error: e);
    }
  }
}
