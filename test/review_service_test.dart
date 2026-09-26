// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review_platform_interface/in_app_review_platform_interface.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/review_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeInAppReviewPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements InAppReviewPlatform {
  bool isAvailableResult = true;
  int isAvailableCalls = 0;
  int requestReviewCalls = 0;
  int openStoreListingCalls = 0;
  String? lastAppStoreId;
  bool shouldThrowOnRequest = false;

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    return isAvailableResult;
  }

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (shouldThrowOnRequest) {
      throw Exception('Play Store unavailable');
    }
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    openStoreListingCalls++;
    lastAppStoreId = appStoreId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppReviewPlatform fakePlatform;
  late LocalStorageService storage;
  late ReviewService reviewService;

  setUp(() async {
    fakePlatform = FakeInAppReviewPlatform();
    InAppReviewPlatform.instance = fakePlatform;

    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();

    reviewService = ReviewService();
    reviewService.resetSessionForTesting();
  });

  group('ReviewService - Home & Completion Rules', () {
    test('shouldShowOnHome requires at least 1 completed artwork', () {
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 0),
        isFalse,
      );
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 1),
        isTrue,
      );
    });

    test('dismissOnHome suppresses prompt on home for the rest of current session', () {
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 2),
        isTrue,
      );

      // User dismisses on home
      reviewService.dismissOnHome();

      // Should not show on home again in this session
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 2),
        isFalse,
      );

      // On next app session (reset), it shows again if not rated
      reviewService.resetSessionForTesting();
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 2),
        isTrue,
      );
    });

    test('shouldShowOnCompletion shows on every artwork complete if user has not rated', () {
      // 0 completions -> false
      expect(
        reviewService.shouldShowOnCompletion(storage: storage, completedCount: 0),
        isFalse,
      );

      // 1st completion -> true
      expect(
        reviewService.shouldShowOnCompletion(storage: storage, completedCount: 1),
        isTrue,
      );

      // 2nd completion -> true (shows on every completion)
      expect(
        reviewService.shouldShowOnCompletion(storage: storage, completedCount: 2),
        isTrue,
      );

      // 10th completion -> true
      expect(
        reviewService.shouldShowOnCompletion(storage: storage, completedCount: 10),
        isTrue,
      );
    });

    test('submitRating sets hasRated to true and invokes in-app review only (no store redirect)', () async {
      expect(reviewService.hasRated(storage), isFalse);

      await reviewService.submitRating(storage: storage, stars: 5);

      expect(reviewService.hasRated(storage), isTrue);
      expect(fakePlatform.requestReviewCalls, 1);
      expect(fakePlatform.openStoreListingCalls, 0); // Must NOT redirect to store

      // Once rated, neither home nor completion should ever prompt again
      expect(
        reviewService.shouldShowOnHome(storage: storage, completedCount: 5),
        isFalse,
      );
      expect(
        reviewService.shouldShowOnCompletion(storage: storage, completedCount: 5),
        isFalse,
      );
    });

    test('requestInAppReview invokes native in-app review without opening store listing', () async {
      await reviewService.requestInAppReview(storage: storage);

      expect(reviewService.hasRated(storage), isTrue);
      expect(fakePlatform.requestReviewCalls, 1);
      expect(fakePlatform.openStoreListingCalls, 0); // In-app only
    });
  });

  group('ReviewService - Platform & Direct Calls', () {
    test('does not request review if completedCount < 1', () async {
      await reviewService.maybeRequestReview(storage: storage, completedCount: 0);

      expect(fakePlatform.isAvailableCalls, 0);
      expect(fakePlatform.requestReviewCalls, 0);
    });

    test('requests review if completedCount >= 1 and not rated', () async {
      await reviewService.maybeRequestReview(storage: storage, completedCount: 1);

      expect(fakePlatform.isAvailableCalls, 1);
      expect(fakePlatform.requestReviewCalls, 1);

      final lastMs = storage.getInt('review_last_request_ms');
      expect(lastMs, greaterThan(0));
    });

    test('openStoreListing calls platform openStoreListing', () async {
      await reviewService.openStoreListing(appStoreId: 'test_store_id');

      expect(fakePlatform.openStoreListingCalls, 1);
      expect(fakePlatform.lastAppStoreId, 'test_store_id');
    });
  });
}
