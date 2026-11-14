import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import 'analytics_service.dart';

class IAPService {
  static final IAPService _instance = IAPService._();
  factory IAPService() => _instance;
  IAPService._();

  bool _storeAvailable = false;
  final Map<String, ProductDetails> _productDetailsCache = {};

  bool get isStoreAvailable => _storeAvailable;
  Map<String, ProductDetails> get cachedProductDetails => Map.unmodifiable(_productDetailsCache);

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
      if (!await InAppPurchase.instance.isAvailable()) {
        AnalyticsService().logRestoreFailed(errorCode: 'store_unavailable');
        return;
      }
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      developer.log('restorePurchases failed', name: 'IAP', error: e);
      AnalyticsService().logRestoreFailed(errorCode: e.toString());
    }
  }

  /// Localized store price for [productId] (e.g. "₹250.00"), or null when
  /// the store is unavailable.
  Future<String?> getPrice(String productId) async {
    if (!_enabled) return null;
    if (_productDetailsCache.containsKey(productId)) {
      return _productDetailsCache[productId]?.price;
    }
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        productId,
      });
      if (response.productDetails.isEmpty) return null;
      final details = response.productDetails.first;
      _productDetailsCache[productId] = details;
      return details.price;
    } catch (_) {
      return null;
    }
  }

  /// Queries ProductDetails for a set of product IDs in a single batch.
  Future<List<ProductDetails>> getProductDetails(Set<String> productIds) async {
    if (!_enabled || productIds.isEmpty) return [];
    try {
      final response = await InAppPurchase.instance.queryProductDetails(productIds);
      for (final p in response.productDetails) {
        _productDetailsCache[p.id] = p;
      }
      return response.productDetails;
    } catch (e) {
      developer.log('queryProductDetails failed for $productIds', name: 'IAP', error: e);
      return [];
    }
  }

  Future<bool> buyProduct(
    ProductDetails productDetails, {
    bool consumable = true,
    String? applicationUserName,
  }) async {
    if (!_enabled) return false;
    try {
      AnalyticsService().logPurchaseStart(productId: productDetails.id);
      _productDetailsCache[productDetails.id] = productDetails;
      final PurchaseParam param = _createPurchaseParam(
        productDetails,
        applicationUserName: applicationUserName,
      );
      if (consumable) {
        return await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      } else {
        return await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      developer.log('buyProduct failed for ${productDetails.id}', name: 'IAP', error: e);
      return false;
    }
  }

  Future<bool> buyPro({String? applicationUserName}) =>
      _buy(AppConstants.proProductId, consumable: false, applicationUserName: applicationUserName);

  /// Starts the Play/App Store billing flow for a Plus subscription. On both
  /// stores subscriptions go through the non-consumable path; renewals and
  /// cancellations then surface via [purchaseStream] restore events.
  Future<bool> buySubscription(String productId, {String? applicationUserName}) =>
      _buy(productId, consumable: false, applicationUserName: applicationUserName);

  Future<bool> buyConsumable(String productId, {String? applicationUserName}) =>
      _buy(productId, consumable: true, applicationUserName: applicationUserName);

  Future<bool> buyDiamondPack(String productId, {String? applicationUserName}) =>
      buyConsumable(productId, applicationUserName: applicationUserName);

  PurchaseParam _createPurchaseParam(
    ProductDetails productDetails, {
    String? applicationUserName,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        productDetails is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
      );
    }
    return PurchaseParam(
      productDetails: productDetails,
      applicationUserName: applicationUserName,
    );
  }

  Future<bool> _buy(
    String productId, {
    required bool consumable,
    String? applicationUserName,
  }) async {
    if (!_enabled) return false;
    try {
      AnalyticsService().logPurchaseStart(productId: productId);
      final purchase = InAppPurchase.instance;

      ProductDetails? details = _productDetailsCache[productId];
      if (details == null) {
        final response = await purchase.queryProductDetails({productId});
        if (response.productDetails.isNotEmpty) {
          details = response.productDetails.first;
          _productDetailsCache[productId] = details;
        }
      }

      if (details == null) {
        developer.log('Product $productId not found in store catalog', name: 'IAP');
        return false;
      }

      final param = _createPurchaseParam(
        details,
        applicationUserName: applicationUserName,
      );

      if (consumable) {
        return await purchase.buyConsumable(purchaseParam: param);
      } else {
        return await purchase.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      developer.log('Purchase flow failed for $productId', name: 'IAP', error: e);
      return false;
    }
  }

  void dispose() {}
}

