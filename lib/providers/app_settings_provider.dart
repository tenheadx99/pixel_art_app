import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';

class AppSettingsProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _isProUser = false;
  bool _isDarkMode = false;
  bool _colorblindMode = false;
  bool _hapticsEnabled = true;
  int _hintsAvailable = 0;

  AppSettingsProvider(this._storageService);

  bool get isProUser => _isProUser;
  bool get isDarkMode => _isDarkMode;
  bool get colorblindMode => _colorblindMode;
  bool get hapticsEnabled => _hapticsEnabled;
  int get hintsAvailable => _hintsAvailable;

  Future<void> loadSettings() async {
    _isProUser = _storageService.getBool(AppConstants.proPrefKey);
    _isDarkMode = _storageService.getBool(AppConstants.darkModePrefKey, defaultValue: true);
    _colorblindMode = _storageService.getBool('colorblind_mode');
    _hapticsEnabled = _storageService.getBool(
      'haptics_enabled',
      defaultValue: true,
    );
    _hintsAvailable = _storageService.getInt(AppConstants.hintsPrefKey);
    notifyListeners();
  }

  void toggleHaptics() {
    _hapticsEnabled = !_hapticsEnabled;
    _storageService.setBool('haptics_enabled', _hapticsEnabled);
    notifyListeners();
  }

  void setProUser(bool value) {
    _isProUser = value;
    _storageService.setBool(AppConstants.proPrefKey, value);
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _storageService.setBool(AppConstants.darkModePrefKey, _isDarkMode);
    notifyListeners();
  }

  void toggleColorblindMode() {
    _colorblindMode = !_colorblindMode;
    _storageService.setBool('colorblind_mode', _colorblindMode);
    notifyListeners();
  }

  void addHints(int count) {
    _hintsAvailable += count;
    _storageService.setInt(AppConstants.hintsPrefKey, _hintsAvailable);
    notifyListeners();
  }

  /// Credits purchased wands directly into storage. ColoringProvider owns the
  /// in-memory count; an open coloring screen re-syncs via this notification.
  void addWands(int count) {
    final current = _storageService.getInt(
      AppConstants.magicWandsPrefKey,
      defaultValue: 5,
    );
    _storageService.setInt(AppConstants.magicWandsPrefKey, current + count);
    notifyListeners();
  }

  bool useHint() {
    if (_hintsAvailable <= 0) return false;
    _hintsAvailable--;
    _storageService.setInt(AppConstants.hintsPrefKey, _hintsAvailable);
    notifyListeners();
    return true;
  }

  void listenToIAP(Stream<List<PurchaseDetails>> stream) {
    _purchaseSub?.cancel();
    _purchaseSub = stream.listen((purchaseDetailsList) async {
      for (final purchase in purchaseDetailsList) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (purchase.productID == AppConstants.proProductId) {
            setProUser(true);
          } else if (purchase.productID == AppConstants.hintProductId) {
            if (purchase.status == PurchaseStatus.purchased) {
              addHints(AppConstants.hintsPerPurchase);
            }
          } else if (purchase.productID == AppConstants.wandPackProductId) {
            if (purchase.status == PurchaseStatus.purchased) {
              addWands(AppConstants.wandsPerPurchase);
            }
          }
        } else if (purchase.status == PurchaseStatus.error) {
          developer.log(
            'Purchase failed for ${purchase.productID}',
            name: 'IAP',
            error: purchase.error,
          );
        }
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      }
    });
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
