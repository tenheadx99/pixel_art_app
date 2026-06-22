import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/app_constants.dart';

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
  bool _isMagicWandMode = false;
  int _magicWandsCount = 5;
  bool _isBombMode = false;
  int _bombsCount = 5;
  bool _isEraseMode = false;
  int _brushSize = 1;
  int _brushesCount = 5;
  (int, int)? _nextFillable;
  int _totalFillCount = 0;
  int _totalEraseCount = 0;
  int _consecutiveFills = 0;
  List<(int, int)> _timeLapse = [];
  // Progress-bar milestones (percent ints, e.g. 30/65/100) already claimed for
  // the current art. Persisted so re-coloring never re-grants a gift.
  Set<int> _claimedMilestones = {};
  Set<String> _achievements = {};
  String? _lastUnlockedAchievement;
  bool _inStroke = false;
  bool _strokeChanged = false;
  int _strokeTimeLapseStart = 0;
  final Map<int, int> _totalPerNumber = {};
  final Map<int, int> _filledPerNumber = {};

  VoidCallback? onCellFilledCorrectly;
  VoidCallback? onSectionCompleted;

  Set<int> _getCompletedNumbers() {
    final completed = <int>{};
    for (final entry in _totalPerNumber.entries) {
      final num = entry.key;
      final total = entry.value;
      final filled = _filledPerNumber[num] ?? 0;
      if (filled == total && total > 0) {
        completed.add(num);
      }
    }
    return completed;
  }

  bool _runWithCompletionCheck(bool Function() action) {
    final previouslyCompleted = _getCompletedNumbers();
    final result = action();
    if (result) {
      final newlyCompleted = _getCompletedNumbers();
      final completedNow = newlyCompleted.difference(previouslyCompleted);
      if (completedNow.isNotEmpty) {
        onSectionCompleted?.call();
      }
    }
    return result;
  }

  bool get isMagicWandMode => _isMagicWandMode;
  int get magicWandsCount => _magicWandsCount;
  bool get isBombMode => _isBombMode;
  int get bombsCount => _bombsCount;
  int get brushesCount => _brushesCount;

  void toggleMagicWandMode() {
    _isMagicWandMode = !_isMagicWandMode;
    if (_isMagicWandMode) {
      _isEraseMode = false;
      _isBombMode = false;
      _haptic(HapticFeedback.selectionClick);
    }
    notifyListeners();
  }

  void toggleBombMode() {
    _isBombMode = !_isBombMode;
    if (_isBombMode) {
      _isMagicWandMode = false;
      _isEraseMode = false;
      _haptic(HapticFeedback.selectionClick);
    }
    notifyListeners();
  }

  void addMagicWands(int count) {
    _magicWandsCount += count;
    _storageService.setInt(AppConstants.magicWandsPrefKey, _magicWandsCount);
    notifyListeners();
  }

  void addBombs(int count) {
    _bombsCount += count;
    _storageService.setInt('bombs_count', _bombsCount);
    notifyListeners();
  }

  void addBrushes(int count) {
    _brushesCount += count;
    _storageService.setInt('brushes_count', _brushesCount);
    notifyListeners();
  }

  /// Re-reads the wand count after an external write (e.g. an IAP credit
  /// applied by AppSettingsProvider while this screen is open).
  void syncWandsFromStorage() {
    final wands = _storageService.getInt(AppConstants.magicWandsPrefKey, defaultValue: -1);
    if (wands >= 0 && wands != _magicWandsCount) {
      _magicWandsCount = wands;
      notifyListeners();
    }
  }

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
  String? get lastUnlockedAchievement => _lastUnlockedAchievement;

  void clearLastUnlockedAchievement() {
    _lastUnlockedAchievement = null;
  }

  String get _saveKey => 'pixelart_progress_${_currentArt?.id ?? ''}';
  /// Achievements persist under one global key (not per-art), so other screens
  /// (e.g. the profile) can read earned badges without loading an artwork.
  static const String achievementsStorageKey = 'pixelart_achievements';
  String get _achieveKey => achievementsStorageKey;

  /// Plays [haptic] unless the user disabled haptics in settings.
  void _haptic(void Function() haptic) {
    if (_storageService.getBool('haptics_enabled', defaultValue: true)) {
      haptic();
    }
  }

  void saveProgress() {
    if (_currentArt == null) return;
    final data = _filledGrid.map((row) => row.join(',')).join(';');
    _storageService.setString(_saveKey, data);
    _storageService.setInt('${_saveKey}_fills', _totalFillCount);
    _storageService.setInt('${_saveKey}_erases', _totalEraseCount);
    // Persist the paint history so Replay / Share GIF keep working when a
    // finished artwork is reopened later (the in-memory list is reset on load).
    _storageService.setString(
      '${_saveKey}_timelapse',
      _timeLapse.map((a) => '${a.$1},${a.$2}').join(';'),
    );
    _storageService.setString(
      '${_saveKey}_milestones',
      _claimedMilestones.join(','),
    );
    // Lightweight percent so list screens can show progress without parsing
    // the full grid string.
    _storageService.setInt('${_saveKey}_pct', (_progress * 100).round());
    _storageService.setString(_achieveKey, _achievements.join(','));
    _storageService.setInt(AppConstants.magicWandsPrefKey, _magicWandsCount);
    _storageService.setInt('bombs_count', _bombsCount);
    _storageService.setInt('brushes_count', _brushesCount);
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
    final ach = _storageService.getString(_achieveKey);
    if (ach.isNotEmpty) _achievements = ach.split(',').toSet();
    // -1 means "never saved": only then grant the starting wands. A stored 0
    // must stay 0, otherwise spent wands come back on every reload.
    final wands = _storageService.getInt(AppConstants.magicWandsPrefKey, defaultValue: -1);
    _magicWandsCount = wands >= 0 ? wands : 5;
    final bombs = _storageService.getInt('bombs_count', defaultValue: -1);
    _bombsCount = bombs >= 0 ? bombs : 5;
    final brushes = _storageService.getInt('brushes_count', defaultValue: -1);
    _brushesCount = brushes >= 0 ? brushes : 5;
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
    _restoreTimeLapse();
    _restoreMilestones();
    _calculateProgress();
    _isComplete = _progress >= AppConfig.completionThreshold;
  }

  /// Rebuilds the paint history from storage so Replay / Share GIF work on a
  /// reopened (e.g. already-completed) artwork. Tolerant of malformed entries.
  void _restoreTimeLapse() {
    final raw = _storageService.getString('${_saveKey}_timelapse');
    if (raw.isEmpty) {
      _timeLapse = [];
      return;
    }
    final restored = <(int, int)>[];
    for (final pair in raw.split(';')) {
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r != null && c != null) restored.add((r, c));
    }
    _timeLapse = restored;
  }

  void _restoreMilestones() {
    final raw = _storageService.getString('${_saveKey}_milestones');
    if (raw.isEmpty) {
      _claimedMilestones = {};
      return;
    }
    _claimedMilestones =
        raw.split(',').map((v) => int.tryParse(v)).whereType<int>().toSet();
  }

  /// Whether [percent] milestone (e.g. 30/65/100) has already paid out.
  bool isMilestoneClaimed(int percent) => _claimedMilestones.contains(percent);

  /// Marks [percent] milestone claimed. Returns false if it was already claimed
  /// or the artwork hasn't reached it yet, so callers grant the reward once.
  bool claimMilestone(int percent) {
    if (_claimedMilestones.contains(percent)) return false;
    if ((_progress * 100).round() < percent) return false;
    _claimedMilestones.add(percent);
    _storageService.setString(
      '${_saveKey}_milestones',
      _claimedMilestones.join(','),
    );
    return true;
  }

  void clearProgress() {
    if (_currentArt == null) return;
    _storageService.setString(_saveKey, '');
    _storageService.setInt('${_saveKey}_pct', 0);
    _storageService.setString('${_saveKey}_timelapse', '');
    _storageService.setString('${_saveKey}_milestones', '');
    _timeLapse = [];
    _claimedMilestones = {};
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
    _selectedNumber = art.sortedNumbers.isNotEmpty
        ? art.sortedNumbers.first
        : 1;
    _progress = 0.0;
    _isComplete = false;
    _undoStack = [];
    _timeLapse = [];
    _claimedMilestones = {};
    _consecutiveFills = 0;
    loadProgress();
    _calculateProgress();
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
    if (_isEraseMode) {
      _haptic(HapticFeedback.selectionClick);
    }
    notifyListeners();
  }

  void setBrushSize(int size) {
    if (size > 1 && _brushesCount <= 0) {
      _brushSize = 1;
    } else {
      _brushSize = size.clamp(1, 3);
    }
    notifyListeners();
  }

  void _updateNextFillable() {
    if (_currentArt == null) {
      _nextFillable = null;
      return;
    }
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber &&
            _filledGrid[row][col] == 0) {
          _nextFillable = (row, col);
          return;
        }
      }
    }
    _nextFillable = null;
  }

  bool tryFillCell(int row, int col) {
    return _runWithCompletionCheck(() {
      if (_currentArt == null) return false;
      if (row < 0 || row >= _currentArt!.gridHeight) return false;
      if (col < 0 || col >= _currentArt!.gridWidth) return false;

      if (_isMagicWandMode) {
        return _tryMagicWandFill(row, col);
      }

      if (_isBombMode) {
        return _tryBombFill(row, col);
      }

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
          onCellFilledCorrectly?.call();
        }
      }

      if (!anyFilled) {
        _undoStack.removeLast();
        return false;
      }

      _haptic(HapticFeedback.lightImpact);

      _totalFillCount++;
      _consecutiveFills++;
      if (_brushSize > 1) {
        if (_brushesCount > 0) {
          _brushesCount--;
          if (_brushesCount == 0) {
            _brushSize = 1;
          }
        }
      }
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      _debouncedSave();
      notifyListeners();
      return true;
    });
  }

  /// Starts a drag stroke: one undo entry covers the whole stroke and the
  /// stroke counts as a single fill for stats/streaks.
  void beginStroke() {
    if (_currentArt == null || _inStroke) return;
    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);
    _inStroke = true;
    _strokeChanged = false;
    _strokeTimeLapseStart = _timeLapse.length;
  }

  /// Reverts an in-progress stroke, e.g. when a drag turns into a two-finger
  /// pinch and the painted cells should not stick.
  void cancelStroke() {
    if (!_inStroke) return;
    _inStroke = false;
    _filledGrid = _undoStack.removeLast();
    _timeLapse.removeRange(_strokeTimeLapseStart, _timeLapse.length);
    if (_strokeChanged) {
      _calculateProgress();
      _updateNextFillable();
    }
    notifyListeners();
  }

  void strokeFill(int row, int col) {
    if (!_inStroke || _currentArt == null) return;
    if (row < 0 || row >= _currentArt!.gridHeight) return;
    if (col < 0 || col >= _currentArt!.gridWidth) return;

    bool changed = false;
    final half = _brushSize ~/ 2;
    for (var dr = -half; dr <= half; dr++) {
      for (var dc = -half; dc <= half; dc++) {
        final r = row + dr;
        final c = col + dc;
        if (r < 0 || r >= _currentArt!.gridHeight) continue;
        if (c < 0 || c >= _currentArt!.gridWidth) continue;
        if (_isEraseMode) {
          if (_filledGrid[r][c] <= 0) continue;
          _filledGrid[r][c] = 0;
          changed = true;
        } else {
          final expectedNumber = _currentArt!.grid[r][c];
          if (expectedNumber == 0) continue;
          if (_filledGrid[r][c] > 0) continue;
          if (expectedNumber != _selectedNumber) continue;
          _filledGrid[r][c] = expectedNumber;
          _timeLapse.add((r, c));
          changed = true;
          onCellFilledCorrectly?.call();
        }
      }
    }
    if (changed) {
      _strokeChanged = true;
      _calculateProgress();
      notifyListeners();
    }
  }

  void endStroke() {
    if (!_inStroke) return;
    _inStroke = false;
    if (!_strokeChanged) {
      _undoStack.removeLast();
      return;
    }
    final previouslyCompleted = _getCompletedNumbers();
    if (_isEraseMode) {
      _totalEraseCount++;
      _consecutiveFills = 0;
      _isComplete = false;
    } else {
      _haptic(HapticFeedback.lightImpact);
      _totalFillCount++;
      _consecutiveFills++;
      if (_brushSize > 1) {
        if (_brushesCount > 0) {
          _brushesCount--;
          if (_brushesCount == 0) {
            _brushSize = 1;
          }
        }
      }
      _checkCompletion();
    }
    _checkAchievements();
    _updateNextFillable();
    _autoAdvanceIfDone();
    _debouncedSave();

    final newlyCompleted = _getCompletedNumbers();
    final completedNow = newlyCompleted.difference(previouslyCompleted);
    if (completedNow.isNotEmpty) {
      onSectionCompleted?.call();
    }

    notifyListeners();
  }

  /// Fills one correct cell as a hint and returns its position, or null if
  /// nothing is left to fill. Prefers the selected number, then any number.
  (int, int)? applyHint() {
    if (_currentArt == null) return null;
    final previouslyCompleted = _getCompletedNumbers();
    _updateNextFillable();
    var target = _nextFillable;
    if (target == null) {
      outer:
      for (var row = 0; row < _currentArt!.gridHeight; row++) {
        for (var col = 0; col < _currentArt!.gridWidth; col++) {
          if (_currentArt!.grid[row][col] > 0 && _filledGrid[row][col] == 0) {
            target = (row, col);
            break outer;
          }
        }
      }
    }
    if (target == null) return null;
    final (r, c) = target;
    final number = _currentArt!.grid[r][c];
    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);
    _selectedNumber = number;
    _highlightedNumber = number;
    _filledGrid[r][c] = number;
    _timeLapse.add((r, c));
    _haptic(HapticFeedback.lightImpact);
    _totalFillCount++;
    onCellFilledCorrectly?.call();
    _calculateProgress();
    _checkCompletion();
    _checkAchievements();
    _updateNextFillable();
    _autoAdvanceIfDone();
    _debouncedSave();

    final newlyCompleted = _getCompletedNumbers();
    final completedNow = newlyCompleted.difference(previouslyCompleted);
    if (completedNow.isNotEmpty) {
      onSectionCompleted?.call();
    }

    notifyListeners();
    return target;
  }

  /// When the selected number has no cells left, moves the selection to the
  /// next number that still has unfilled cells.
  void _autoAdvanceIfDone() {
    if (_currentArt == null || _nextFillable != null || _isComplete) return;
    final numbers = _currentArt!.sortedNumbers;
    final start = numbers.indexOf(_selectedNumber);
    for (var i = 1; i <= numbers.length; i++) {
      final candidate = numbers[(start + i) % numbers.length];
      if (_hasUnfilled(candidate)) {
        _selectedNumber = candidate;
        _highlightedNumber = candidate;
        _updateNextFillable();
        return;
      }
    }
  }

  bool _hasUnfilled(int number) =>
      (_filledPerNumber[number] ?? 0) < (_totalPerNumber[number] ?? 0);

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

  void fillAllOfSelectedNumber() {
    if (_currentArt == null) return;
    final previouslyCompleted = _getCompletedNumbers();
    bool changed = false;
    _pushUndoState();
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber &&
            _filledGrid[row][col] == 0) {
          _filledGrid[row][col] = _selectedNumber;
          _timeLapse.add((row, col));
          changed = true;
          onCellFilledCorrectly?.call();
        }
      }
    }
    if (changed) {
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      saveProgress();

      final newlyCompleted = _getCompletedNumbers();
      final completedNow = newlyCompleted.difference(previouslyCompleted);
      if (completedNow.isNotEmpty) {
        onSectionCompleted?.call();
      }

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

  /// Recomputes overall progress and the per-number tallies in one pass.
  /// The tallies feed the palette chips and auto-advance, which previously
  /// rescanned the whole grid per color on every rebuild.
  void _calculateProgress() {
    if (_currentArt == null) return;
    _totalPerNumber.clear();
    _filledPerNumber.clear();
    int filled = 0;
    int total = 0;
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        final n = _currentArt!.grid[row][col];
        if (n <= 0) continue;
        total++;
        _totalPerNumber[n] = (_totalPerNumber[n] ?? 0) + 1;
        if (_filledGrid[row][col] > 0) {
          filled++;
          _filledPerNumber[n] = (_filledPerNumber[n] ?? 0) + 1;
        }
      }
    }
    _progress = total == 0 ? 1.0 : filled / total;
  }

  double fillPercentForNumber(int number) {
    final total = _totalPerNumber[number] ?? 0;
    if (total == 0) return 0;
    return (_filledPerNumber[number] ?? 0) / total;
  }

  /// Cells filled for [number] / total cells of that number — drives the
  /// "18/50" count on the palette chips.
  (int, int) cellCountsForNumber(int number) =>
      (_filledPerNumber[number] ?? 0, _totalPerNumber[number] ?? 0);

  /// Total coloured cells across all numbers (for completion stats).
  int get filledCellCount =>
      _filledPerNumber.values.fold(0, (sum, v) => sum + v);

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
    _lastUnlockedAchievement = id;
    saveProgress();
    notifyListeners();
  }

  /// All achievements in unlock order (id -> display name). Used by the profile
  /// screen to render earned vs. still-locked badges.
  static const Map<String, String> achievementCatalog = {
    'complete_first': 'First Masterpiece',
    'fill_10': 'Getting Started',
    'fill_100': 'Dedicated Artist',
    'fill_500': 'Pixel Master',
    'streak_10': 'In the Zone',
    'streak_25': 'Unstoppable',
    'eraser_10': 'Second Thoughts',
  };

  String achievementName(String id) => achievementCatalog[id] ?? id;

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

  bool _tryMagicWandFill(int row, int col) {
    if (_magicWandsCount <= 0) {
      _isMagicWandMode = false;
      notifyListeners();
      return false;
    }
    final targetNum = _currentArt!.grid[row][col];
    if (targetNum == 0 || _filledGrid[row][col] > 0) return false;

    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);

    final queue = <(int, int)>[(row, col)];
    final visited = <(int, int)>{};
    bool changed = false;

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final r = curr.$1;
      final c = curr.$2;

      if (r < 0 ||
          r >= _currentArt!.gridHeight ||
          c < 0 ||
          c >= _currentArt!.gridWidth) {
        continue;
      }
      if (visited.contains((r, c))) continue;
      visited.add((r, c));

      if (_currentArt!.grid[r][c] == targetNum && _filledGrid[r][c] == 0) {
        _filledGrid[r][c] = targetNum;
        _timeLapse.add((r, c));
        changed = true;
        onCellFilledCorrectly?.call();

        queue.add((r + 1, c));
        queue.add((r - 1, c));
        queue.add((r, c + 1));
        queue.add((r, c - 1));
      }
    }

    if (changed) {
      _magicWandsCount--;
      _isMagicWandMode = false;
      _totalFillCount++;
      _haptic(HapticFeedback.mediumImpact);
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      saveProgress();
      notifyListeners();
      return true;
    } else {
      _undoStack.removeLast();
      return false;
    }
  }

  bool _tryBombFill(int row, int col) {
    if (_bombsCount <= 0) {
      _isBombMode = false;
      notifyListeners();
      return false;
    }

    _pushUndoState();
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);

    bool changed = false;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = row + dr;
        final c = col + dc;
        if (r < 0 || r >= _currentArt!.gridHeight) continue;
        if (c < 0 || c >= _currentArt!.gridWidth) continue;
        final expectedNumber = _currentArt!.grid[r][c];
        if (expectedNumber == 0) continue;
        if (_filledGrid[r][c] > 0) continue;
        _filledGrid[r][c] = expectedNumber;
        _timeLapse.add((r, c));
        changed = true;
        onCellFilledCorrectly?.call();
      }
    }

    if (changed) {
      _bombsCount--;
      _isBombMode = false;
      _totalFillCount++;
      _haptic(HapticFeedback.mediumImpact);
      _calculateProgress();
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      saveProgress();
      notifyListeners();
      return true;
    } else {
      _undoStack.removeLast();
      return false;
    }
  }
}
