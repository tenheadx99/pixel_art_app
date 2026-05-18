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

  String get _saveKey => 'pixelart_progress_${_currentArt?.id ?? ''}';

  void saveProgress() {
    if (_currentArt == null) return;
    final data = _filledGrid.map((row) => row.join(',')).join(';');
    _storageService.setString(_saveKey, data);
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
    _calculateProgress();
    _isComplete = _progress >= AppConfig.completionThreshold;
  }

  void clearProgress() {
    if (_currentArt == null) return;
    _storageService.setString(_saveKey, '');
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
    loadProgress();
    notifyListeners();
  }

  void selectNumber(int number) {
    _selectedNumber = number;
    _highlightedNumber = number;
    notifyListeners();
  }

  void clearHighlight() {
    _highlightedNumber = null;
    notifyListeners();
  }

  void toggleNumbers() {
    _showNumbers = !_showNumbers;
    notifyListeners();
  }

  bool tryFillCell(int row, int col) {
    if (_currentArt == null) return false;
    if (row < 0 || row >= _currentArt!.gridHeight) return false;
    if (col < 0 || col >= _currentArt!.gridWidth) return false;

    final expectedNumber = _currentArt!.grid[row][col];
    if (expectedNumber == 0) return false;
    if (_filledGrid[row][col] > 0) return false;
    if (expectedNumber != _selectedNumber) return false;

    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) {
      _undoStack.removeAt(0);
    }

    _filledGrid[row][col] = expectedNumber;
    _calculateProgress();
    _checkCompletion();
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
          changed = true;
        }
      }
    }
    if (changed) {
      _calculateProgress();
      _checkCompletion();
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
        if (_currentArt!.grid[row][col] == _selectedNumber &&
            _filledGrid[row][col] == 0) {
          _filledGrid[row][col] = _selectedNumber;
          changed = true;
        }
      }
    }

    if (changed) {
      _calculateProgress();
      _checkCompletion();
      saveProgress();
      notifyListeners();
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _filledGrid = _undoStack.removeLast();
    _calculateProgress();
    _isComplete = false;
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
        if (_currentArt!.grid[row][col] > 0 && _filledGrid[row][col] > 0) {
          filled++;
        }
      }
    }
    _progress = filled / total;
  }

  void _checkCompletion() {
    if (_progress >= AppConfig.completionThreshold) {
      _isComplete = true;
    }
  }

  List<List<int>> getGridState() {
    return _filledGrid.map((row) => List<int>.from(row)).toList();
  }

  void restoreGridState(List<List<int>> state) {
    _filledGrid = state.map((row) => List<int>.from(row)).toList();
    _calculateProgress();
    if (_progress >= AppConfig.completionThreshold) {
      _isComplete = true;
    }
    notifyListeners();
  }
}
