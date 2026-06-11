import 'package:in_app_purchase/in_app_purchase.dart';
import '../../config/app_config.dart';
import '../../config/app_constants.dart';

class IAPService {
  static final IAPService _instance = IAPService._();
  factory IAPService() => _instance;
  IAPService._();

  final InAppPurchase _purchase = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseStream => _purchase.purchaseStream;

  Future<bool> initialize() async {
    if (AppConfig.disableIap) return true;
    final available = await _purchase.isAvailable();
    return available;
  }

  /// Re-delivers past non-consumable purchases (e.g. Pro) through
  /// [purchaseStream] as [PurchaseStatus.restored] events. Call after a
  /// listener is attached, or the events are lost.
  Future<void> restorePurchases() async {
    if (AppConfig.disableIap) return;
    if (!await _purchase.isAvailable()) return;
    await _purchase.restorePurchases();
  }

  Future<void> buyPro() async {
    if (AppConfig.disableIap) return;
    final productDetails = await _purchase.queryProductDetails({
      AppConstants.proProductId,
    });
    if (productDetails.productDetails.isEmpty) return;
    final purchaseParam = PurchaseParam(
      productDetails: productDetails.productDetails.first,
    );
    await _purchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> buyConsumable(String productId) async {
    if (AppConfig.disableIap) return;
    final productDetails = await _purchase.queryProductDetails({productId});
    if (productDetails.productDetails.isEmpty) return;
    final purchaseParam = PurchaseParam(
      productDetails: productDetails.productDetails.first,
    );
    await _purchase.buyConsumable(purchaseParam: purchaseParam);
  }

  void dispose() {}
}
