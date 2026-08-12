import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/models/split_art.dart';
import 'package:pixel_art_app/data/services/daily_pixel_service.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_catalog_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/ad_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

class GalleryProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  final DatabaseService _databaseService;
  final RemoteCatalogService? _remoteCatalogService;
  final DailyPixelService? _dailyPixelService;

  List<PixelArt> _catalog = [];
  Set<String> _completedIds = {};
  Set<String> _favoriteIds = {};
  String _selectedCategory = 'All';
  bool _isLoading = false;

  GalleryProvider(
    this._storageService,
    this._databaseService, [
    this._remoteCatalogService,
    this._dailyPixelService,
  ]);

  List<PixelArt> get catalog => _catalog;
  Set<String> get completedIds => _completedIds;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  bool _favoritesOnly = false;
  String _sortBy =
      'Default'; // Options: Default, Difficulty (Easy), Difficulty (Hard), Colors (Few), Colors (Many)

  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get favoritesOnly => _favoritesOnly;

  /// True when the listing is narrowed by category, search or favorites — lets
  /// the empty state distinguish "no matches" from "no catalog".
  bool get hasActiveFilter =>
      _selectedCategory != 'All' || _searchQuery.isNotEmpty || _favoritesOnly;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _favoritesOnly = !_favoritesOnly;
    notifyListeners();
  }

  /// Resets every listing filter back to the default "show all" view.
  void clearFilters() {
    _selectedCategory = 'All';
    _searchQuery = '';
    _favoritesOnly = false;
    notifyListeners();
  }

  void setSortBy(String option) {
    _sortBy = option;
    notifyListeners();
  }

  List<PixelArt> get filteredCatalog {
    var list = _catalog;
    if (_selectedCategory != 'All') {
      list = list.where((a) => a.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.category.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_favoritesOnly) {
      list = list.where((a) => _favoriteIds.contains(a.id)).toList();
    }

    if (_sortBy == 'Difficulty (Easy)') {
      list = List.from(list)
        ..sort(
          (a, b) => (a.gridWidth * a.gridHeight).compareTo(
            b.gridWidth * b.gridHeight,
          ),
        );
    } else if (_sortBy == 'Difficulty (Hard)') {
      list = List.from(list)
        ..sort(
          (a, b) => (b.gridWidth * b.gridHeight).compareTo(
            a.gridWidth * a.gridHeight,
          ),
        );
    } else if (_sortBy == 'Colors (Few)') {
      list = List.from(list)
        ..sort((a, b) => a.colorCount.compareTo(b.colorCount));
    } else if (_sortBy == 'Colors (Many)') {
      list = List.from(list)
        ..sort((a, b) => b.colorCount.compareTo(a.colorCount));
    }

    return list;
  }

  List<String> get categories {
    final cats = <String>{'All'};
    for (final art in _catalog) {
      cats.add(art.category);
    }
    return cats.toList()..sort();
  }

  Future<void> loadCatalog(List<PixelArt> preMade) async {
    _isLoading = true;
    notifyListeners();

    _catalog = preMade;
    _completedIds = _storageService.getStringSet(
      AppConstants.completedIdsPrefKey,
    );
    _favoriteIds = _storageService.getStringSet('favorite_ids');
    _diamondUnlockedIds = _storageService.getStringSet(_diamondUnlockedPrefKey);
    _loadStreak();

    _isLoading = false;
    notifyListeners();
  }

  /// Replaces the catalog once the remote (admin-published) merge lands.
  /// User state (completed/favorites/progress) is keyed by art id and needs
  /// no migration.
  void updateCatalog(List<PixelArt> catalog) {
    _catalog = catalog;
    // The selected category may have been renamed/hidden by the update.
    if (_selectedCategory != 'All' &&
        !_catalog.any((a) => a.category == _selectedCategory)) {
      _selectedCategory = 'All';
    }
    notifyListeners();
  }

  // --- Daily Pixel & Streak Insurance ---

  static const String _streakPrefKey = 'daily_streak';
  static const String _streakDatePrefKey = 'daily_last_date';
  static const String _bestStreakPrefKey = 'daily_best_streak';
  static const String _streakFreezesPrefKey = 'streak_freezes';
  static const String _streakBrokenAtPrefKey = 'streak_broken_at_ms';
  static const String _streakBrokenValuePrefKey = 'streak_broken_value';
  static const String _plusFreezeMonthPrefKey = 'plus_freeze_month';

  /// Date the daily artwork itself was completed. Drives the banner "done"
  /// state and the streak-bonus claim — distinct from [_streakDatePrefKey],
  /// which any completed artwork can advance.
  static const String _dailyDoneDatePrefKey = 'daily_done_date';

  /// Per-day pin: `daily_art_id_<yyyy-MM-dd>` -> art id. Written once by
  /// [resolveDailyArt]; while pinned, the daily cannot change mid-day even if
  /// an admin publish reshuffles the catalog.
  static const String _dailyPinPrefix = 'daily_art_id_';

  int _dailyStreak = 0;
  int _bestStreak = 0;
  int _streakFreezes = 0;
  int _streakBrokenAtMs = 0;
  int _streakBrokenValue = 0;

  int get dailyStreak => _dailyStreak;
  int get bestStreak => _bestStreak;
  int get streakFreezes => _streakFreezes;
  int get streakBrokenAtMs => _streakBrokenAtMs;
  int get streakBrokenValue => _streakBrokenValue;

  bool get canRepairStreak {
    if (_streakBrokenValue <= 0 || _streakBrokenAtMs <= 0) return false;
    final diffMs = DateTime.now().millisecondsSinceEpoch - _streakBrokenAtMs;
    return diffMs >= 0 && diffMs <= 48 * 3600 * 1000;
  }

  static PixelArt? dailyArtFor(DateTime date, List<PixelArt> catalog) =>
      DailyPixelService.fallbackDailyFor(date, catalog);

  /// Today's Daily Pixel. Prefers the id pinned by [resolveDailyArt]; until a
  /// pin lands (first frame, or offline with a cold schedule cache) it serves
  /// the deterministic fallback rotation.
  PixelArt? get dailyArt {
    final pinnedId = _storageService.getString(
      '$_dailyPinPrefix${_dateKey(DateTime.now())}',
    );
    final pinned = _catalog.firstWhereOrNull((a) => a.id == pinnedId);
    return pinned ??
        DailyPixelService.fallbackDailyFor(DateTime.now(), _catalog);
  }

  /// Resolves and pins today's daily: admin schedule doc first, deterministic
  /// fallback otherwise. Called after the remote catalog merge so a scheduled
  /// remote artwork is actually present in the catalog. When the schedule is
  /// unreachable (offline, cold cache) today stays unpinned — [dailyArt]
  /// serves the fallback and the next launch retries.
  Future<void> resolveDailyArt() async {
    final service = _dailyPixelService;
    if (service == null || _catalog.isEmpty) return;
    final pinPrefKey = '$_dailyPinPrefix${_dateKey(DateTime.now())}';
    if (_storageService.getString(pinPrefKey).isNotEmpty) return;
    final String? scheduledId;
    try {
      scheduledId = await service.scheduledArtId(_dateKey(DateTime.now()));
    } catch (_) {
      return;
    }
    final art = _catalog.firstWhereOrNull((a) => a.id == scheduledId) ??
        DailyPixelService.fallbackDailyFor(DateTime.now(), _catalog);
    if (art == null) return;
    _storageService.setString(pinPrefKey, art.id);
    notifyListeners();
  }

  bool get dailyCompletedToday =>
      _storageService.getString(_dailyDoneDatePrefKey) ==
      _dateKey(DateTime.now());

  void _loadStreak() {
    _dailyStreak = _storageService.getInt(_streakPrefKey);
    _bestStreak = _storageService.getInt(_bestStreakPrefKey);
    _streakFreezes = _storageService.getInt(_streakFreezesPrefKey);
    _streakBrokenAtMs = _storageService.getInt(_streakBrokenAtPrefKey);
    _streakBrokenValue = _storageService.getInt(_streakBrokenValuePrefKey);

    final last = _storageService.getString(_streakDatePrefKey);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    // Migration: before the pin/widen release, the streak date advancing
    // meant the daily itself was completed. Seed the new done-date once so
    // upgraders don't see today's already-finished daily flip back to "to do".
    if (_storageService.getString(_dailyDoneDatePrefKey).isEmpty &&
        last == _dateKey(today)) {
      _storageService.setString(_dailyDoneDatePrefKey, last);
    }
    // Missed a day (or more): check freeze or break streak.
    if (last.isNotEmpty &&
        last != _dateKey(today) &&
        last != _dateKey(yesterday)) {
      if (_streakFreezes > 0) {
        _streakFreezes--;
        _storageService.setInt(_streakFreezesPrefKey, _streakFreezes);
        _storageService.setString(_streakDatePrefKey, _dateKey(yesterday));
        AnalyticsService().logDailyRewardClaimed(
          dayStreak: _dailyStreak,
          coins: 0,
        );
      } else {
        if (_dailyStreak > 0) {
          _streakBrokenAtMs = DateTime.now().millisecondsSinceEpoch;
          _streakBrokenValue = _dailyStreak;
          _storageService.setInt(_streakBrokenAtPrefKey, _streakBrokenAtMs);
          _storageService.setInt(_streakBrokenValuePrefKey, _streakBrokenValue);
        }
        _dailyStreak = 0;
        _storageService.setInt(_streakPrefKey, 0);
      }
    } else if (!canRepairStreak && _streakBrokenValue > 0) {
      _streakBrokenAtMs = 0;
      _streakBrokenValue = 0;
      _storageService.setInt(_streakBrokenAtPrefKey, 0);
      _storageService.setInt(_streakBrokenValuePrefKey, 0);
    }
  }

  bool buyStreakFreeze(AppSettingsProvider settings) {
    if (_streakFreezes >= 2) return false;
    if (settings.useDiamonds(150)) {
      _streakFreezes++;
      _storageService.setInt(_streakFreezesPrefKey, _streakFreezes);
      notifyListeners();
      return true;
    }
    return false;
  }

  void checkAndGrantPlusMonthlyFreeze(bool isPlusActive) {
    if (!isPlusActive) return;
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastGranted = _storageService.getString(_plusFreezeMonthPrefKey);
    if (lastGranted != currentMonth) {
      _storageService.setString(_plusFreezeMonthPrefKey, currentMonth);
      if (_streakFreezes < 2) {
        _streakFreezes++;
        _storageService.setInt(_streakFreezesPrefKey, _streakFreezes);
        notifyListeners();
      }
    }
  }

  bool repairStreakWithDiamonds(AppSettingsProvider settings) {
    if (!canRepairStreak) return false;
    if (settings.useDiamonds(300)) {
      _restoreStreak();
      return true;
    }
    return false;
  }

  void repairStreakWithAd(AdService adService, VoidCallback onRewarded) {
    if (!canRepairStreak) return;
    adService.showRewardedAd(
      placement: 'streak_repair',
      onRewarded: () {
        _restoreStreak();
        onRewarded();
      },
    );
  }

  void _restoreStreak() {
    _dailyStreak = _streakBrokenValue;
    _storageService.setInt(_streakPrefKey, _dailyStreak);
    final todayStr = _dateKey(DateTime.now());
    final yesterdayStr = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final last = _storageService.getString(_streakDatePrefKey);
    if (last != todayStr) {
      _storageService.setString(_streakDatePrefKey, yesterdayStr);
    }
    if (_dailyStreak > _bestStreak) {
      _bestStreak = _dailyStreak;
      _storageService.setInt(_bestStreakPrefKey, _bestStreak);
    }
    _streakBrokenAtMs = 0;
    _streakBrokenValue = 0;
    _storageService.setInt(_streakBrokenAtPrefKey, 0);
    _storageService.setInt(_streakBrokenValuePrefKey, 0);
    notifyListeners();
  }

  void _registerDailyCompletion() {
    final today = _dateKey(DateTime.now());
    final last = _storageService.getString(_streakDatePrefKey);
    if (last == today) return;
    final yesterday = _dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    _dailyStreak = last == yesterday ? _dailyStreak + 1 : 1;
    _storageService.setInt(_streakPrefKey, _dailyStreak);
    _storageService.setString(_streakDatePrefKey, today);
    AnalyticsService().logDailyRewardClaimed(dayStreak: _dailyStreak, coins: 0);
    if (_dailyStreak > _bestStreak) {
      _bestStreak = _dailyStreak;
      _storageService.setInt(_bestStreakPrefKey, _bestStreak);
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Saved coloring progress (0-100) for [id]; written by ColoringProvider.
  int progressPercent(String id) =>
      _storageService.getInt('pixelart_progress_${id}_pct');

  /// Fillable cell counts per part, memoized per parent id (one 36k-cell scan
  /// for a 192x192 parent; the catalog instance is stable between updates).
  final Map<String, List<int>> _partFillableCache = {};

  List<int> _partFillables(PixelArt parent) => _partFillableCache.putIfAbsent(
    parent.id,
    () => SplitArt.partFillableCounts(parent),
  );

  /// Progress (0-100) for [art], aggregating part saves for split artworks
  /// weighted by each part's fillable cells. Empty parts count as complete.
  int artProgressPercent(PixelArt art) {
    if (!art.isSplit) return progressPercent(art.id);
    final fillables = _partFillables(art);
    int total = 0;
    int done = 0;
    for (int i = 0; i < art.partCount; i++) {
      total += fillables[i];
      done += fillables[i] * partProgressPercent(art, i);
    }
    return total == 0 ? 100 : done ~/ total;
  }

  /// Progress (0-100) of part [index] of a split [parent]. Parts with no
  /// fillable cells are always 100 (there is nothing to color).
  int partProgressPercent(PixelArt parent, int index) {
    if (_partFillables(parent)[index] == 0) return 100;
    return progressPercent(SplitArt.partId(parent.id, index));
  }

  /// Whether every (non-empty) part of a split [parent] is fully colored.
  bool partsAllComplete(PixelArt parent) {
    for (int i = 0; i < parent.partCount; i++) {
      if (partProgressPercent(parent, i) < 100) return false;
    }
    return true;
  }

  /// Timestamp (ms since epoch) of latest coloring progress saved for [art].
  int artProgressTimestamp(PixelArt art) {
    int maxTs = _storageService.getInt('pixelart_progress_${art.id}_ts');
    if (art.isSplit) {
      for (int i = 0; i < art.partCount; i++) {
        final partId = SplitArt.partId(art.id, i);
        final partTs =
            _storageService.getInt('pixelart_progress_${partId}_ts');
        if (partTs > maxTs) maxTs = partTs;
      }
    }
    return maxTs;
  }

  /// Artworks the user has started but not finished, ordered by most recently
  /// colored first (recency timestamp) and capped at 10 items.
  List<PixelArt> get inProgressArts {
    final list = _catalog.where((a) {
      final p = artProgressPercent(a);
      return p > 0 && p < 100;
    }).toList();
    list.sort(
      (a, b) => artProgressTimestamp(b).compareTo(artProgressTimestamp(a)),
    );
    return list.take(10).toList();
  }

  /// Re-reads derived state (e.g. after returning from the coloring screen).
  void refresh() => notifyListeners();

  bool isCompleted(String id) => _completedIds.contains(id);

  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    _storageService.setStringList('favorite_ids', _favoriteIds.toList());
    notifyListeners();
  }

  void markCompleted(String id) {
    _completedIds.add(id);
    _storageService.addToStringSet(AppConstants.completedIdsPrefKey, id);
    if (SplitArt.isPartId(id)) {
      // Parts are user-invisible sub-artworks: no completion stats for them.
      // Finishing the last part completes the parent (stats reported once).
      final parentId = SplitArt.parentIdOf(id);
      final parent = _catalog.where((a) => a.id == parentId).firstOrNull;
      if (parent != null &&
          !isCompleted(parent.id) &&
          partsAllComplete(parent)) {
        markCompleted(parent.id);
        return;
      }
      notifyListeners();
      return;
    }
    _databaseService.incrementCompleted(id);
    _remoteCatalogService?.reportCompletion(id);
    if (id == dailyArt?.id) {
      _storageService.setString(
        _dailyDoneDatePrefKey,
        _dateKey(DateTime.now()),
      );
    }
    // Any finished artwork keeps the streak alive (at most once per day); the
    // daily itself additionally flips the banner/bonus state above. A streak
    // that only advanced on one specific piece punished users who coloured
    // three other things that day.
    _registerDailyCompletion();
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Premium pieces a rewarded ad unlocked for this app session only.
  final Set<String> _sessionUnlockedIds = {};

  /// Premium pieces permanently unlocked by spending diamonds. Persisted, so
  /// the unlock survives restarts (the user paid currency for it).
  static const String _diamondUnlockedPrefKey = 'diamond_unlocked_ids';
  Set<String> _diamondUnlockedIds = {};

  void unlockForSession(String id) {
    _sessionUnlockedIds.add(id);
    notifyListeners();
  }

  /// Permanently unlocks [id] after a diamond purchase.
  void unlockWithDiamonds(String id) {
    _diamondUnlockedIds.add(id);
    _storageService.addToStringSet(_diamondUnlockedPrefKey, id);
    notifyListeners();
  }

  bool isUnlocked(PixelArt art, bool isProUser) {
    if (!art.isPremium) {
      return true;
    }
    return isProUser ||
        _sessionUnlockedIds.contains(art.id) ||
        _diamondUnlockedIds.contains(art.id);
  }
}
