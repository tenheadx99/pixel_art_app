import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import 'analytics_service.dart';

class IAPService {
  static final IAPService _instance = IAPService._();
  factory IAPService() => _instance;
  IAPService._();

  bool _storeAvailable = false;

  bool get isStoreAvailable => _storeAvailable;

  /// in_app_purchase only registers a platform implementation on
  /// Android/iOS/macOS. Anywhere else (Linux/Windows desktop debug runs,
  /// tests) touching InAppPurchase.instance throws a LateInitializationError,
  /// so every entry point bails out first.
  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _enabled => !AppConfig.disableIap && _platformSupported;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _enabled ? InAppPurchase.instance.purchaseStream : const Stream.empty();

  Future<bool> initialize() async {
    if (!_enabled) return false;
    try {
      _storeAvailable = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      developer.log('IAP unavailable', name: 'IAP', error: e);
      _storeAvailable = false;
    }
    return _storeAvailable;
  }

  /// Re-delivers past non-consumable purchases (e.g. Pro) through
  /// [purchaseStream] as [PurchaseStatus.restored] events. Call after a
  /// listener is attached, or the events are lost.
  Future<void> restorePurchases() async {
    if (!_enabled) return;
    try {
      if (!await InAppPurchase.instance.isAvailable()) return;
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      developer.log('restorePurchases failed', name: 'IAP', error: e);
    }
  }

  /// Localized store price for [productId] (e.g. "₹250.00"), or null when
  /// the store is unavailable.
  Future<String?> getPrice(String productId) async {
    if (!_enabled) return null;
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        productId,
      });
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first.price;
    } catch (_) {
      return null;
    }
  }

  Future<void> buyPro() => _buy(AppConstants.proProductId, consumable: false);

  /// Starts the Play/App Store billing flow for a Plus subscription. On both
  /// stores subscriptions go through the non-consumable path; renewals and
  /// cancellations then surface via [purchaseStream] restore events.
  Future<void> buySubscription(String productId) =>
      _buy(productId, consumable: false);

  Future<void> buyConsumable(String productId) =>
      _buy(productId, consumable: true);

  Future<void> _buy(String productId, {required bool consumable}) async {
    if (!_enabled) return;
    try {
      AnalyticsService().logPurchaseStart(productId: productId);
      final purchase = InAppPurchase.instance;
      final response = await purchase.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return;
      final param = PurchaseParam(
        productDetails: response.productDetails.first,
      );
      if (consumable) {
        await purchase.buyConsumable(purchaseParam: param);
      } else {
        await purchase.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      developer.log('Purchase flow failed for $productId', name: 'IAP', error: e);
    }
  }

  void dispose() {}
}
