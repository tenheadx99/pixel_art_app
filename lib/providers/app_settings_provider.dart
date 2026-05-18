import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';

class AppSettingsProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  bool _isProUser = false;
  bool _isDarkMode = false;

  AppSettingsProvider(this._storageService);

  bool get isProUser => _isProUser;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadSettings() async {
    _isProUser = _storageService.getBool(AppConstants.proPrefKey);
    _isDarkMode = _storageService.getBool(AppConstants.darkModePrefKey);
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

  void listenToIAP(Stream<List<PurchaseDetails>> stream) {
    stream.listen((purchaseDetailsList) {
      for (final purchase in purchaseDetailsList) {
        if (purchase.status == PurchaseStatus.purchased) {
          if (purchase.productID == AppConstants.proProductId) {
            setProUser(true);
          }
        }
      }
    });
  }
}
