import 'package:flutter/material.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_constants.dart';

class GalleryProvider extends ChangeNotifier {
  final LocalStorageService _storageService;
  final DatabaseService _databaseService;

  List<PixelArt> _catalog = [];
  Set<String> _completedIds = {};
  Set<String> _favoriteIds = {};
  String _selectedCategory = 'All';
  bool _isLoading = false;

  GalleryProvider(this._storageService, this._databaseService);

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

  // --- Daily Pixel ---

  static const String _streakPrefKey = 'daily_streak';
  static const String _streakDatePrefKey = 'daily_last_date';
  int _dailyStreak = 0;

  int get dailyStreak => _dailyStreak;

  /// Deterministic featured artwork for [date]: same pick for everyone all
  /// day, rotating through the whole catalog. No backend needed.
  static PixelArt? dailyArtFor(DateTime date, List<PixelArt> catalog) {
    if (catalog.isEmpty) return null;
    final dayNumber = DateTime(date.year, date.month, date.day)
        .difference(DateTime(2026))
        .inDays;
    return catalog[dayNumber.abs() % catalog.length];
  }

  PixelArt? get dailyArt => dailyArtFor(DateTime.now(), _catalog);

  bool get dailyCompletedToday =>
      _storageService.getString(_streakDatePrefKey) == _dateKey(DateTime.now());

  void _loadStreak() {
    _dailyStreak = _storageService.getInt(_streakPrefKey);
    final last = _storageService.getString(_streakDatePrefKey);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    // Missed a day (or more): the streak is broken.
    if (last.isNotEmpty &&
        last != _dateKey(today) &&
        last != _dateKey(yesterday)) {
      _dailyStreak = 0;
      _storageService.setInt(_streakPrefKey, 0);
    }
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
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Saved coloring progress (0-100) for [id]; written by ColoringProvider.
  int progressPercent(String id) =>
      _storageService.getInt('pixelart_progress_${id}_pct');

  /// Artworks the user has started but not finished, for a "continue" row.
  List<PixelArt> get inProgressArts => _catalog.where((a) {
    final p = progressPercent(a.id);
    return p > 0 && p < 100;
  }).toList();

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
    _databaseService.incrementCompleted(id);
    if (id == dailyArt?.id) _registerDailyCompletion();
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
    if (!art.isPremium) return true;
    return isProUser ||
        _sessionUnlockedIds.contains(art.id) ||
        _diamondUnlockedIds.contains(art.id);
  }
}
