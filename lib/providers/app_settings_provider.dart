import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/notification_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';

class AppSettingsProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _isProUser = false;
  bool _isDarkMode = false;
  bool _colorblindMode = false;
  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
  String _soundType = 'bubble_pop';
  bool _dailyRemindersEnabled = true;
  int _hintsAvailable = 0;
  int _diamondsAvailable = 320;

  static const String _dailyRemindersPrefKey = 'daily_reminders_enabled';

  AppSettingsProvider(this._storageService);

  bool get isProUser => _isProUser;
  bool get isDarkMode => _isDarkMode;
  bool get colorblindMode => _colorblindMode;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get soundsEnabled => _soundsEnabled;
  String get soundType => _soundType;
  bool get dailyRemindersEnabled => _dailyRemindersEnabled;
  int get hintsAvailable => _hintsAvailable;
  int get diamondsAvailable => _diamondsAvailable;

  Future<void> loadSettings() async {
    _isProUser = _storageService.getBool(AppConstants.proPrefKey);
    _isDarkMode = _storageService.getBool(AppConstants.darkModePrefKey, defaultValue: true);
    _colorblindMode = _storageService.getBool('colorblind_mode');
    _hapticsEnabled = _storageService.getBool(
      'haptics_enabled',
      defaultValue: true,
    );
    _soundsEnabled = _storageService.getBool('sounds_enabled', defaultValue: true);
    _soundType = _storageService.getString('sound_type', defaultValue: 'bubble_pop');
    _dailyRemindersEnabled = _storageService.getBool(
      _dailyRemindersPrefKey,
      defaultValue: true,
    );
    _hintsAvailable = _storageService.getInt(AppConstants.hintsPrefKey);
    _diamondsAvailable = _storageService.getInt('diamonds_available', defaultValue: 320);
    notifyListeners();
  }

  void toggleHaptics() {
    _hapticsEnabled = !_hapticsEnabled;
    _storageService.setBool('haptics_enabled', _hapticsEnabled);
    notifyListeners();
  }

  void toggleSounds() {
    _soundsEnabled = !_soundsEnabled;
    _storageService.setBool('sounds_enabled', _soundsEnabled);
    notifyListeners();
  }

  void setSoundType(String type) {
    _soundType = type;
    _storageService.setString('sound_type', type);
    notifyListeners();
  }

  /// Toggles daily reminders. Turning them on requests OS notification
  /// permission first; if the user denies it the toggle reverts to off so the
  /// UI never claims reminders are active when the OS won't deliver them.
  Future<void> setDailyRemindersEnabled(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        _dailyRemindersEnabled = false;
        _storageService.setBool(_dailyRemindersPrefKey, false);
        notifyListeners();
        return;
      }
      await NotificationService.instance.scheduleDailyReminders();
    } else {
      await NotificationService.instance.cancelAll();
    }
    _dailyRemindersEnabled = enabled;
    _storageService.setBool(_dailyRemindersPrefKey, enabled);
    notifyListeners();
  }

  /// Re-queues reminders on app launch so the on-device schedule stays topped
  /// up with rotating copy. No-op (and clears any stale schedule) when the
  /// user has reminders turned off.
  Future<void> syncDailyReminders() async {
    if (_dailyRemindersEnabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (granted) {
        await NotificationService.instance.scheduleDailyReminders();
      }
    } else {
      await NotificationService.instance.cancelAll();
    }
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

  void addDiamonds(int count) {
    _diamondsAvailable += count;
    _storageService.setInt('diamonds_available', _diamondsAvailable);
    notifyListeners();
  }

  bool useDiamonds(int count) {
    if (_diamondsAvailable < count) return false;
    _diamondsAvailable -= count;
    _storageService.setInt('diamonds_available', _diamondsAvailable);
    notifyListeners();
    return true;
  }

  /// Pays out the completion reward for [artId] exactly once. Adds a daily
  /// bonus when [isDaily] is true. Returns the diamonds awarded (0 if this art
  /// was already rewarded), so the UI can celebrate the actual amount.
  int awardCompletionDiamonds(String artId, {bool isDaily = false}) {
    final key = '${AppConstants.diamondsAwardedPrefix}$artId';
    if (_storageService.getBool(key)) return 0;
    final amount = AppConstants.diamondsPerCompletion +
        (isDaily ? AppConstants.diamondsDailyBonus : 0);
    _storageService.setBool(key, true);
    addDiamonds(amount);
    return amount;
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
