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

  List<PixelArt> get filteredCatalog {
    if (_selectedCategory == 'All') return _catalog;
    return _catalog.where((a) => a.category == _selectedCategory).toList();
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
    _completedIds = _storageService.getStringSet(AppConstants.completedIdsPrefKey);
    _favoriteIds = _storageService.getStringSet('favorite_ids');

    _isLoading = false;
    notifyListeners();
  }

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
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  bool isUnlocked(PixelArt art, bool isProUser) {
    if (!art.isPremium) return true;
    return isProUser;
  }
}
