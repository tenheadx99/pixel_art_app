import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_config.dart';

class ColoringProvider extends ChangeNotifier {
  final LocalStorageService _storageService;

  PixelArt? _currentArt;
  List<List<int>> _filledGrid = [];
  Map<int, Color> _filledColors = {};
  int _selectedNumber = 1;
  double _progress = 0.0;
  bool _isComplete = false;
  List<List<List<int>>> _undoStack = [];
  bool _showNumbers = true;
  int? _highlightedNumber;
  Timer? _saveTimer;
  bool _isEraseMode = false;
  int _brushSize = 1;
  (int, int)? _nextFillable;
  int _totalFillCount = 0;
  int _totalEraseCount = 0;
  int _consecutiveFills = 0;
  List<(int, int)> _timeLapse = [];
  Set<String> _achievements = {};

  ColoringProvider(this._storageService);

  PixelArt? get currentArt => _currentArt;
  List<List<int>> get filledGrid => _filledGrid;
  Map<int, Color> get filledColors => _filledColors;
  int get selectedNumber => _selectedNumber;
  double get progress => _progress;
  bool get isComplete => _isComplete;
  bool get showNumbers => _showNumbers;
  int? get highlightedNumber => _highlightedNumber;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get isEraseMode => _isEraseMode;
  int get brushSize => _brushSize;
  (int, int)? get nextFillable => _nextFillable;
  int get totalFillCount => _totalFillCount;
  int get totalEraseCount => _totalEraseCount;
  int get consecutiveFills => _consecutiveFills;
  List<(int, int)> get timeLapse => _timeLapse;
  Set<String> get achievements => _achievements;

  String get _saveKey => 'pixelart_progress_${_currentArt?.id ?? ''}';
  String get _achieveKey => 'pixelart_achievements';
  String get _statsKey => 'pixelart_stats';

  void saveProgress() {
    if (_currentArt == null) return;
    final data = _filledGrid.map((row) => row.join(',')).join(';');
    _storageService.setString(_saveKey, data);
    _storageService.setInt('${_saveKey}_fills', _totalFillCount);
    _storageService.setInt('${_saveKey}_erases', _totalEraseCount);
    _storageService.setString(_achieveKey, _achievements.join(','));
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(AppConfig.autoSaveDelay, saveProgress);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void loadProgress() {
    if (_currentArt == null) return;
    final raw = _storageService.getString(_saveKey);
    if (raw.isEmpty) return;
    final rows = raw.split(';');
    if (rows.length != _currentArt!.gridHeight) return;
    final loaded = <List<int>>[];
    for (var r = 0; r < rows.length; r++) {
      final cols = rows[r].split(',');
      if (cols.length != _currentArt!.gridWidth) return;
      loaded.add(cols.map((v) => int.tryParse(v) ?? 0).toList());
    }
    _filledGrid = loaded;
    _totalFillCount = _storageService.getInt('${_saveKey}_fills');
    _totalEraseCount = _storageService.getInt('${_saveKey}_erases');
    final ach = _storageService.getString(_achieveKey);
    if (ach.isNotEmpty) _achievements = ach.split(',').toSet();
    _calculateProgress();
    _isComplete = _progress >= AppConfig.completionThreshold;
  }

  void clearProgress() {
    if (_currentArt == null) return;
    _storageService.setString(_saveKey, '');
    _timeLapse = [];
    _consecutiveFills = 0;
  }

  bool cellIsFilled(int row, int col) {
    if (row < 0 || row >= _filledGrid.length) return false;
    if (col < 0 || col >= _filledGrid[0].length) return false;
    return _filledGrid[row][col] > 0;
  }

  Color? cellFillColor(int row, int col) {
    if (!cellIsFilled(row, col)) return null;
    return _filledColors[_filledGrid[row][col]];
  }

  void loadArt(PixelArt art) {
    _currentArt = art;
    _filledGrid = List.generate(
      art.gridHeight,
      (_) => List.filled(art.gridWidth, 0),
    );
    _filledColors = Map.from(art.colorMap);
    _selectedNumber = art.sortedNumbers.isNotEmpty ? art.sortedNumbers.first : 1;
    _progress = 0.0;
    _isComplete = false;
    _undoStack = [];
    _timeLapse = [];
    _consecutiveFills = 0;
    loadProgress();
    notifyListeners();
  }

  void selectNumber(int number) {
    _selectedNumber = number;
    _highlightedNumber = number;
    _updateNextFillable();
    notifyListeners();
  }

  void clearHighlight() {
    _highlightedNumber = null;
    _nextFillable = null;
    notifyListeners();
  }

  void toggleNumbers() {
    _showNumbers = !_showNumbers;
    notifyListeners();
  }

  void toggleEraseMode() {
    _isEraseMode = !_isEraseMode;
    notifyListeners();
  }

  void setBrushSize(int size) {
    _brushSize = size.clamp(1, 3);
    notifyListeners();
  }

  void _updateNextFillable() {
    if (_currentArt == null) {
      _nextFillable = null;
      return;
    }
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber && _filledGrid[row][col] == 0) {
          _nextFillable = (row, col);
          return;
        }
      }
    }
    _nextFillable = null;
  }

  bool tryFillCell(int row, int col) {
    if (_currentArt == null) return false;
    if (row < 0 || row >= _currentArt!.gridHeight) return false;
    if (col < 0 || col >= _currentArt!.gridWidth) return false;

    if (_isEraseMode) {
      return tryEraseCell(row, col);
    }

    final half = _brushSize ~/ 2;
    bool anyFilled = false;
    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);

    for (var dr = -half; dr <= half; dr++) {
      for (var dc = -half; dc <= half; dc++) {
        final r = row + dr;
        final c = col + dc;
        if (r < 0 || r >= _currentArt!.gridHeight) continue;
        if (c < 0 || c >= _currentArt!.gridWidth) continue;
        final expectedNumber = _currentArt!.grid[r][c];
        if (expectedNumber == 0) continue;
        if (_filledGrid[r][c] > 0) continue;
        if (expectedNumber != _selectedNumber) continue;
        _filledGrid[r][c] = expectedNumber;
        _timeLapse.add((r, c));
        anyFilled = true;
      }
    }

    if (!anyFilled) {
      _undoStack.removeLast();
      return false;
    }

    _totalFillCount += anyFilled ? 1 : 0;
    _consecutiveFills = anyFilled ? _consecutiveFills + 1 : 0;
    _calculateProgress();
    _checkCompletion();
    _checkAchievements();
    _updateNextFillable();
    _debouncedSave();
    notifyListeners();
    return true;
  }

  bool tryEraseCell(int row, int col) {
    if (_currentArt == null) return false;
    if (row < 0 || row >= _currentArt!.gridHeight) return false;
    if (col < 0 || col >= _currentArt!.gridWidth) return false;
    if (_filledGrid[row][col] <= 0) return false;

    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);

    _filledGrid[row][col] = 0;
    _totalEraseCount++;
    _consecutiveFills = 0;
    _calculateProgress();
    _isComplete = false;
    _updateNextFillable();
    _debouncedSave();
    notifyListeners();
    return true;
  }

  void fillAllRemaining() {
    if (_currentArt == null) return;
    bool changed = false;
    _pushUndoState();
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] > 0 && _filledGrid[row][col] == 0) {
          _filledGrid[row][col] = _currentArt!.grid[row][col];
          _timeLapse.add((row, col));
          changed = true;
        }
      }
    }
    if (changed) {
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      saveProgress();
      notifyListeners();
    }
  }

  void fillAllOfSelectedNumber() {
    if (_currentArt == null) return;
    bool changed = false;
    _pushUndoState();
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber && _filledGrid[row][col] == 0) {
          _filledGrid[row][col] = _selectedNumber;
          _timeLapse.add((row, col));
          changed = true;
        }
      }
    }
    if (changed) {
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      saveProgress();
      notifyListeners();
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _filledGrid = _undoStack.removeLast();
    _calculateProgress();
    _isComplete = false;
    _updateNextFillable();
    saveProgress();
    notifyListeners();
  }

  void resetArt() {
    if (_currentArt == null) return;
    _filledGrid = List.generate(
      _currentArt!.gridHeight,
      (_) => List.filled(_currentArt!.gridWidth, 0),
    );
    _progress = 0.0;
    _isComplete = false;
    _undoStack = [];
    _timeLapse = [];
    _consecutiveFills = 0;
    _nextFillable = null;
    clearProgress();
    notifyListeners();
  }

  void _pushUndoState() {
    _undoStack.add(_filledGrid.map((row) => List<int>.from(row)).toList());
  }

  void _calculateProgress() {
    if (_currentArt == null) return;
    final total = _currentArt!.fillableCells;
    if (total == 0) {
      _progress = 1.0;
      return;
    }
    int filled = 0;
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] > 0 && _filledGrid[row][col] > 0) filled++;
      }
    }
    _progress = filled / total;
  }

  void _checkCompletion() {
    if (_progress >= AppConfig.completionThreshold) {
      _isComplete = true;
      _consecutiveFills = 0;
    }
  }

  void _checkAchievements() {
    if (_progress >= 1.0) _addAchievement('complete_first');
    if (_totalFillCount >= 10) _addAchievement('fill_10');
    if (_totalFillCount >= 100) _addAchievement('fill_100');
    if (_totalFillCount >= 500) _addAchievement('fill_500');
    if (_consecutiveFills >= 10) _addAchievement('streak_10');
    if (_consecutiveFills >= 25) _addAchievement('streak_25');
    if (_totalEraseCount >= 10) _addAchievement('eraser_10');
  }

  void _addAchievement(String id) {
    if (_achievements.contains(id)) return;
    _achievements.add(id);
    saveProgress();
    notifyListeners();
  }

  String achievementName(String id) {
    const names = {
      'complete_first': 'First Masterpiece',
      'fill_10': 'Getting Started',
      'fill_100': 'Dedicated Artist',
      'fill_500': 'Pixel Master',
      'streak_10': 'In the Zone',
      'streak_25': 'Unstoppable',
      'eraser_10': 'Second Thoughts',
    };
    return names[id] ?? id;
  }

  void timeLapseStep(int row, int col) {
    if (_currentArt == null) return;
    final num = _currentArt!.grid[row][col];
    if (num > 0 && _filledGrid[row][col] == 0) {
      _filledGrid[row][col] = num;
    }
    notifyListeners();
  }

  List<List<int>> getGridState() {
    return _filledGrid.map((row) => List<int>.from(row)).toList();
  }

  void restoreGridState(List<List<int>> state) {
    _filledGrid = state.map((row) => List<int>.from(row)).toList();
    _calculateProgress();
    if (_progress >= AppConfig.completionThreshold) _isComplete = true;
    _updateNextFillable();
    notifyListeners();
  }
}
