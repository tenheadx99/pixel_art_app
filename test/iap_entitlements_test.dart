import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

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
  });
}
