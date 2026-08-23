import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:math' as math;
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/notification_service.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';

/// Result of an [AppSettingsProvider.addXp] call, so the UI can celebrate a
/// level-up with the reward popup.
class LevelUpResult {
  final bool leveledUp;
  final int newLevel;
  final int diamondsAwarded;

  const LevelUpResult({
    required this.leveledUp,
    required this.newLevel,
    required this.diamondsAwarded,
  });
}

class AppSettingsProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _isProUser = false;
  bool _isRemoveAds = false;
  int _plusExpiryMs = 0;
  bool _isDarkMode = false;
  bool _colorblindMode = false;
  bool _hapticsEnabled = true;
  String _hapticIntensity = 'medium';
  bool _soundsEnabled = true;
  bool _fillEffectsEnabled = true;
  String _soundType = 'bubble_pop';
  String _ambientTrack = 'none';
  double _ambientVolume = 0.5;
  String _particleStyle = 'sparkles';
  bool _dailyRemindersEnabled = true;
  int _hintsAvailable = 3;
  int _diamondsAvailable = 50;
  int _totalXp = 0;
  int _playerLevel = 1;
  int _lifetimeCellsColored = 0;
  Locale? _appLocale;

  static const String _dailyRemindersPrefKey = 'daily_reminders_enabled';
  static const String _totalXpPrefKey = 'total_xp';
  static const String _playerLevelPrefKey = 'player_level';
  static const String _lifetimeCellsPrefKey = 'lifetime_cells_colored';

  AppSettingsProvider(this._storageService);

  /// Pro entitlement: lifetime Pro purchase OR active Plus subscription OR Remove Ads.
  bool get isProUser => _isProUser || isPlusActive || _isRemoveAds;

  /// Whether standalone Remove Ads was purchased.
  bool get isRemoveAds => _isRemoveAds;

  /// Lifetime Pro only (without an active subscription) — for UI that needs
  /// to distinguish the two (e.g. hiding subscription plans from lifetime
  /// owners).
  bool get isLifetimePro => _isProUser;

  bool get isPlusActive =>
      DateTime.now().millisecondsSinceEpoch < _plusExpiryMs;
  bool get isDarkMode => _isDarkMode;
  bool get colorblindMode => _colorblindMode;
  bool get hapticsEnabled => _hapticsEnabled;
  String get hapticIntensity => _hapticIntensity;
  bool get soundsEnabled => _soundsEnabled;
  bool get fillEffectsEnabled => _fillEffectsEnabled;
  String get soundType => _soundType;
  String get ambientTrack => _ambientTrack;
  double get ambientVolume => _ambientVolume;
  String get particleStyle => _particleStyle;
  bool get dailyRemindersEnabled => _dailyRemindersEnabled;
  int get hintsAvailable => _hintsAvailable;
  int get diamondsAvailable => _diamondsAvailable;
  int get totalXp => _totalXp;
  int get playerLevel => _playerLevel;
  int get lifetimeCellsColored => _lifetimeCellsColored;
  Locale? get appLocale => _appLocale;

  void setAppLocale(Locale? locale) {
    _appLocale = locale;
    if (locale == null) {
      _storageService.setString('app_locale', '');
    } else {
      _storageService.setString('app_locale', locale.languageCode);
    }
    notifyListeners();
  }

  /// XP threshold to *enter* [level] (the inverse of the sqrt level curve).
  int xpForLevel(int level) =>
      (level - 1) * (level - 1) * AppConstants.xpLevelDivisor;

  /// Level a given total XP corresponds to: floor(sqrt(xp / divisor)) + 1.
  int levelForXp(int xp) =>
      math.sqrt(xp / AppConstants.xpLevelDivisor).floor() + 1;

  /// Fractional progress (0..1) through the current level, for the XP bar.
  double get xpProgressInLevel {
    final start = xpForLevel(_playerLevel);
    final end = xpForLevel(_playerLevel + 1);
    if (end <= start) return 0;
    return ((_totalXp - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// XP remaining until the next level.
  int get xpToNextLevel =>
      (xpForLevel(_playerLevel + 1) - _totalXp).clamp(0, 1 << 30);

  Future<void> loadSettings() async {
    _isProUser = _storageService.getBool(AppConstants.proPrefKey);
    _isRemoveAds = _storageService.getBool(AppConstants.removeAdsPrefKey);
    _plusExpiryMs = _storageService.getInt(AppConstants.plusExpiryPrefKey);
    // Light theme by default for every flavor; dark mode is opt-in via
    // settings (a saved preference always wins over this default).
    _isDarkMode = _storageService.getBool(AppConstants.darkModePrefKey);
    _colorblindMode = _storageService.getBool('colorblind_mode');
    _hapticsEnabled = _storageService.getBool(
      'haptics_enabled',
      defaultValue: true,
    );
    _hapticIntensity = _storageService.getString(
      'haptic_intensity',
      defaultValue: 'medium',
    );
    _soundsEnabled = _storageService.getBool('sounds_enabled', defaultValue: true);
    _fillEffectsEnabled = _storageService.getBool(
      'fill_effects_enabled',
      defaultValue: true,
    );
    _soundType = _storageService.getString('sound_type', defaultValue: 'bubble_pop');
    _ambientTrack = _storageService.getString('ambient_track', defaultValue: 'none');
    _ambientVolume = _storageService.getDouble('ambient_volume', defaultValue: 0.5);
    _particleStyle = _storageService.getString('particle_style', defaultValue: 'sparkles');
    _dailyRemindersEnabled = _storageService.getBool(
      _dailyRemindersPrefKey,
      defaultValue: true,
    );
    _hintsAvailable = _storageService.getInt(
      AppConstants.hintsPrefKey,
      defaultValue: 3,
    );
    _diamondsAvailable = _storageService.getInt('diamonds_available', defaultValue: 50);
    _totalXp = _storageService.getInt(_totalXpPrefKey);
    _playerLevel = _storageService.getInt(_playerLevelPrefKey, defaultValue: 1);
    _lifetimeCellsColored = _storageService.getInt(_lifetimeCellsPrefKey);
    final localeCode = _storageService.getString('app_locale');
    if (localeCode.isNotEmpty) {
      _appLocale = Locale(localeCode);
    } else {
      _appLocale = null;
    }
    AnalyticsService()
        .setPlayerProperties(level: _playerLevel, isPro: _isProUser);
    notifyListeners();
  }

  /// Adds [amount] XP, persists totals, and rolls the level forward. Returns a
  /// [LevelUpResult] so callers can celebrate; level-ups also grant diamonds.
  LevelUpResult addXp(int amount) {
    if (amount <= 0) {
      return LevelUpResult(
        leveledUp: false,
        newLevel: _playerLevel,
        diamondsAwarded: 0,
      );
    }
    _totalXp += amount;
    _storageService.setInt(_totalXpPrefKey, _totalXp);

    final computedLevel = levelForXp(_totalXp);
    var diamondsAwarded = 0;
    final leveledUp = computedLevel > _playerLevel;
    if (leveledUp) {
      // One reward per level gained (covers multi-level jumps).
      diamondsAwarded =
          (computedLevel - _playerLevel) * AppConstants.diamondsPerLevelUp;
      _playerLevel = computedLevel;
      _storageService.setInt(_playerLevelPrefKey, _playerLevel);
      _diamondsAvailable += diamondsAwarded;
      _storageService.setInt('diamonds_available', _diamondsAvailable);
      AnalyticsService().setPlayerProperties(level: _playerLevel);
    }
    notifyListeners();
    return LevelUpResult(
      leveledUp: leveledUp,
      newLevel: _playerLevel,
      diamondsAwarded: diamondsAwarded,
    );
  }

  /// Accumulates lifetime cells colored (shown on the profile screen).
  void addLifetimeCells(int count) {
    if (count <= 0) return;
    _lifetimeCellsColored += count;
    _storageService.setInt(_lifetimeCellsPrefKey, _lifetimeCellsColored);
    notifyListeners();
  }

  void toggleHaptics() {
    _hapticsEnabled = !_hapticsEnabled;
    _storageService.setBool('haptics_enabled', _hapticsEnabled);
    notifyListeners();
  }

  void setHapticIntensity(String intensity) {
    _hapticIntensity = intensity;
    _storageService.setString('haptic_intensity', _hapticIntensity);
    notifyListeners();
  }

  void toggleSounds() {
    _soundsEnabled = !_soundsEnabled;
    _storageService.setBool('sounds_enabled', _soundsEnabled);
    notifyListeners();
  }

  void toggleFillEffects() {
    _fillEffectsEnabled = !_fillEffectsEnabled;
    _storageService.setBool('fill_effects_enabled', _fillEffectsEnabled);
    notifyListeners();
  }

  void setSoundType(String type) {
    _soundType = type;
    _storageService.setString('sound_type', type);
    notifyListeners();
  }

  void setAmbientTrack(String track) {
    _ambientTrack = track;
    _storageService.setString('ambient_track', track);
    notifyListeners();
  }

  void setAmbientVolume(double volume) {
    _ambientVolume = volume.clamp(0.0, 1.0);
    _storageService.setDouble('ambient_volume', _ambientVolume);
    notifyListeners();
  }

  void setParticleStyle(String style) {
    _particleStyle = style;
    _storageService.setString('particle_style', style);
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

  void setRemoveAds(bool value) {
    _isRemoveAds = value;
    _storageService.setBool(AppConstants.removeAdsPrefKey, value);
    notifyListeners();
  }

  /// Extends the Plus entitlement to [days] from now. Called on every
  /// purchase/restore event for a Plus product, so an active subscription
  /// re-stamps itself each session and a cancelled one quietly runs out.
  void extendPlusEntitlement(int days) {
    final until = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    // Never shorten: a yearly stamp must survive a later monthly event.
    if (until <= _plusExpiryMs) return;
    _plusExpiryMs = until;
    _storageService.setInt(AppConstants.plusExpiryPrefKey, until);
    notifyListeners();
  }

  /// Checks if the new user welcome bonus (50 diamonds) should be claimed on first launch.
  /// Returns 50 on first launch only, 0 for returning users or subsequent launches.
  int checkAndClaimWelcomeBonus() {
    if (_storageService.getBool(AppConstants.welcomeBonusPrefKey)) {
      return 0;
    }
    _storageService.setBool(AppConstants.welcomeBonusPrefKey, true);
    // Ensure diamonds balance reflects the welcome bonus
    if (_diamondsAvailable < AppConstants.diamondsWelcomeBonus) {
      _diamondsAvailable = AppConstants.diamondsWelcomeBonus;
      _storageService.setInt('diamonds_available', _diamondsAvailable);
      notifyListeners();
    }
    return AppConstants.diamondsWelcomeBonus;
  }

  /// Grants the daily Plus diamond stipend once per calendar day. Returns the
  /// amount awarded (0 when not a subscriber or already claimed today) so the
  /// UI can celebrate.
  int maybeClaimDailyPlusStipend() {
    if (!isPlusActive) return 0;
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_storageService.getString(AppConstants.plusStipendDayPrefKey) ==
        today) {
      return 0;
    }
    _storageService.setString(AppConstants.plusStipendDayPrefKey, today);
    addDiamonds(AppConstants.diamondsDailyPlusStipend);
    return AppConstants.diamondsDailyPlusStipend;
  }

  String get _todayStamp {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Free-diamond rewarded claims left today. The shop tile and home pill
  /// draw from this one pool so the Remote Config cap bounds the total faucet.
  int get freeDiamondClaimsRemaining {
    final cap = RemoteConfigService().rewardedDiamondsDailyCap;
    if (_storageService.getString(AppConstants.freeDiamondsDayPrefKey) !=
        _todayStamp) {
      return cap;
    }
    final used = _storageService.getInt(AppConstants.freeDiamondsCountPrefKey);
    return math.max(0, cap - used);
  }

  /// Consumes one capped free-diamond claim and pays out. Returns the amount
  /// granted (0 when today's pool is exhausted) so the UI can celebrate.
  int claimFreeDiamonds() {
    if (freeDiamondClaimsRemaining <= 0) return 0;
    final today = _todayStamp;
    final used =
        _storageService.getString(AppConstants.freeDiamondsDayPrefKey) == today
            ? _storageService.getInt(AppConstants.freeDiamondsCountPrefKey)
            : 0;
    _storageService.setString(AppConstants.freeDiamondsDayPrefKey, today);
    _storageService.setInt(AppConstants.freeDiamondsCountPrefKey, used + 1);
    final amount = RemoteConfigService().rewardedDiamondsAmount;
    addDiamonds(amount);
    return amount;
  }

  bool get dailyStreakBonusClaimedToday =>
      _storageService.getString(AppConstants.streakBonusDayPrefKey) ==
      _todayStamp;

  /// Once-per-day streak bonus behind a rewarded ad on the daily banner.
  /// Returns the amount granted (0 if already claimed today).
  int claimDailyStreakBonus() {
    if (dailyStreakBonusClaimedToday) return 0;
    _storageService.setString(AppConstants.streakBonusDayPrefKey, _todayStamp);
    final amount = RemoteConfigService().dailyStreakAdBonus;
    addDiamonds(amount);
    return amount;
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
      defaultValue: 3,
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
          if (purchase.status == PurchaseStatus.purchased) {
            AnalyticsService().logPurchase(productId: purchase.productID);
          }
          final pId = purchase.productID;
          final rc = RemoteConfigService();
          if (pId == AppConstants.proProductId) {
            setProUser(true);
            AnalyticsService().setPlayerProperties(isPro: true);
          } else if (pId == rc.removeAdsProductId ||
              pId == AppConstants.removeAdsProductId) {
            setRemoveAds(true);
          } else if (pId == rc.plus1DayProductId ||
              pId == AppConstants.plus1DayProductId) {
            extendPlusEntitlement(AppConstants.plus1DayEntitlementDays);
          } else if (pId == rc.plusWeeklyProductId ||
              pId == AppConstants.plusWeeklyProductId) {
            extendPlusEntitlement(AppConstants.plusWeeklyEntitlementDays);
          } else if (pId == rc.plusMonthlyProductId ||
              pId == AppConstants.plusMonthlyProductId) {
            extendPlusEntitlement(AppConstants.plusMonthlyEntitlementDays);
          } else if (pId == rc.plusYearlyProductId ||
              pId == AppConstants.plusYearlyProductId) {
            extendPlusEntitlement(AppConstants.plusYearlyEntitlementDays);
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
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (e) {
            // Play throws when a token is already consumed/acknowledged (e.g.
            // a restore re-delivering an entitlement) or when offline; the
            // entitlement above is already granted, so never crash on this.
            developer.log(
              'completePurchase failed for ${purchase.productID}',
              name: 'IAP',
              error: e,
            );
          }
        }
      }
    }, onError: (Object e) {
      // iOS surfaces store failures as stream errors; without a handler they
      // escape the subscription as uncaught async errors.
      developer.log('Purchase stream error', name: 'IAP', error: e);
    });
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
