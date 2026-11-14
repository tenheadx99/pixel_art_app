import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

class _FakePurchaseDetails extends PurchaseDetails {
  _FakePurchaseDetails({
    required super.productID,
    required super.status,
    super.transactionDate,
  }) : super(
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local',
            serverVerificationData: 'server',
            source: 'google_play',
          ),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IAP & Subscription Entitlements Management', () {
    late LocalStorageService storage;
    late AppSettingsProvider settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      settings = AppSettingsProvider(storage);
    });

    test('shouldRemoveAds vs isProUser separation', () {
      expect(settings.isProUser, isFalse);
      expect(settings.shouldRemoveAds, isFalse);

      // Buying Remove Ads alone suppresses ads but DOES NOT grant Pro privileges
      settings.setRemoveAds(true);
      expect(settings.isRemoveAds, isTrue);
      expect(settings.shouldRemoveAds, isTrue);
      expect(settings.isProUser, isFalse);

      // Activating Pro grants both Pro and ad suppression
      settings.setRemoveAds(false);
      settings.setProUser(true);
      expect(settings.isProUser, isTrue);
      expect(settings.shouldRemoveAds, isTrue);
    });

    test('Immortal subscription fix: expired restore does not extend entitlement', () {
      expect(settings.isPlusActive, isFalse);

      // An old purchase from 60 days ago for a 30-day subscription
      final expiredPurchaseTime = DateTime.now().subtract(const Duration(days: 60));
      settings.extendPlusEntitlement(30, purchaseTime: expiredPurchaseTime, isRestore: true);

      // Must NOT be active because it expired 30 days ago
      expect(settings.isPlusActive, isFalse);
    });

    test('Valid subscription restore correctly activates when within expiration range', () {
      expect(settings.isPlusActive, isFalse);

      // A purchase made 5 days ago for a 30-day subscription
      final validPurchaseTime = DateTime.now().subtract(const Duration(days: 5));
      settings.extendPlusEntitlement(30, purchaseTime: validPurchaseTime, isRestore: true);

      // Must be active
      expect(settings.isPlusActive, isTrue);
    });

    test('Fresh subscription purchase stacks remaining days onto existing active subscription', () {
      expect(settings.isPlusActive, isFalse);

      // User buys 10 days
      settings.extendPlusEntitlement(10);
      final firstExpiry = settings.plusExpiryMs;
      expect(settings.isPlusActive, isTrue);

      // User buys another 30 days while active
      settings.extendPlusEntitlement(30);
      final secondExpiry = settings.plusExpiryMs;

      // New expiry must be at least 30 days after the FIRST expiry (stacked)
      expect(secondExpiry, greaterThanOrEqualTo(firstExpiry + const Duration(days: 29).inMilliseconds));
    });

    test('membershipLabel and plusDaysRemaining return accurate status', () {
      expect(settings.membershipLabel, equals('Free'));
      expect(settings.plusDaysRemaining, equals(0));

      settings.setRemoveAds(true);
      expect(settings.membershipLabel, equals('Ad-Free'));

      settings.setRemoveAds(false);
      settings.extendPlusEntitlement(15);
      expect(settings.membershipLabel, equals('Plus VIP'));
      expect(settings.plusDaysRemaining, inInclusiveRange(14, 15));
      expect(settings.plusExpiryDate, isNotNull);

      settings.setProUser(true);
      expect(settings.membershipLabel, equals('Lifetime VIP'));
    });

    test('resetEntitlementsOnSignOut clears local state and storage', () {
      settings.setProUser(true);
      settings.setRemoveAds(true);
      settings.extendPlusEntitlement(30);

      expect(settings.isProUser, isTrue);
      expect(settings.isRemoveAds, isTrue);
      expect(settings.isPlusActive, isTrue);

      settings.resetEntitlementsOnSignOut();

      expect(settings.isProUser, isFalse);
      expect(settings.isRemoveAds, isFalse);
      expect(settings.isPlusActive, isFalse);
    });

    test('listenToIAP handles subscription and SKU with offer details without crash', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      settings.listenToIAP(controller.stream);

      // 1. Pending status: does NOT grant
      controller.add([
        _FakePurchaseDetails(
          productID: 'pixel_art_plus_monthly',
          status: PurchaseStatus.pending,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(settings.isPlusActive, isFalse);

      // 2. Purchased status with Google Play base-plan suffix (e.g. :monthly-base-plan)
      controller.add([
        _FakePurchaseDetails(
          productID: 'pixel_art_plus_monthly:monthly-base-plan',
          status: PurchaseStatus.purchased,
          transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(settings.isPlusActive, isTrue);
      expect(settings.membershipLabel, equals('Plus VIP'));

      // 3. Lifetime pro purchase
      controller.add([
        _FakePurchaseDetails(
          productID: AppConstants.proProductId,
          status: PurchaseStatus.purchased,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(settings.isProUser, isTrue);
      expect(settings.isLifetimePro, isTrue);

      // 4. Cancelled status: does not throw or crash
      controller.add([
        _FakePurchaseDetails(
          productID: 'pixel_art_plus_yearly',
          status: PurchaseStatus.canceled,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 5. Error status: does not throw or crash
      controller.add([
        _FakePurchaseDetails(
          productID: 'pixel_art_plus_yearly',
          status: PurchaseStatus.error,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await controller.close();
    });
  });
}
