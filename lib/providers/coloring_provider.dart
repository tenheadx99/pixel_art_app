import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show max;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
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

  // Undo entries are diffs — flat [cellIndex, previousValue, ...] pairs for
  // the cells an action actually changed — instead of full-grid snapshots
  // (a 128x128 snapshot copies 16k cells per tap, up to 20 deep).
  final List<List<int>> _undoStack = [];
  List<int>? _currentUndoEntry;

  // Incremental progress state: kept in sync on every cell change so fills
  // never need a full-grid rescan. _calculateProgress() rebuilds them from
  // scratch after wholesale grid changes (load/undo/restore).
  int _fillableTotal = 0;
  int _filledCount = 0;

  // Row-major resume point of the "next fillable" scan per number. Fills only
  // ever move the first unfilled cell forward; anything that un-fills cells
  // (erase/undo/restore) clears the affected cursors.
  final Map<int, int> _fillCursor = {};

  // Bumped on every filledGrid mutation; painters compare it in shouldRepaint
  // so unrelated screen rebuilds don't repaint the whole grid.
  int _gridRevision = 0;

  // Completed-number snapshot taken at beginStroke: tallies update live during
  // the stroke, so a snapshot taken in endStroke could never see a change.
  Set<int> _strokeStartCompleted = const {};

  // Serialized-timelapse cache so each autosave appends only the new entries
  // instead of re-joining the whole history (16k entries on a 128x128).
  String _timeLapseSerialized = '';
  int _timeLapseSerializedCount = 0;
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
  // Fired with the grid coords of a just-filled cell so the UI can spawn a
  // joyful fill effect there. Mass fills (wand/bomb/fill-all) skip this to
  // avoid flooding the effect layer.
  void Function(int row, int col)? onCellFilledAt;

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

  ColoringProvider(this._storageService) {
    _initVibration();
  }

  // --- Reliable haptics ---
  // Flutter's HapticFeedback impact calls map to View.performHapticFeedback,
  // which many Android OEMs implement weakly or not at all. To guarantee a
  // felt buzz we drive the device Vibrator directly via the `vibration`
  // package (Android), falling back to the OS haptic engine on iOS.
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;

  Future<void> _initVibration() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    } catch (_) {
      _hasVibrator = false;
    }
  }

  bool get _hapticsOn =>
      _storageService.getBool('haptics_enabled', defaultValue: true);

  /// Medium-strength buzz on each cell fill. Uses an explicit amplitude where
  /// supported so it's reliably felt regardless of OEM haptic quirks.
  void _fillVibrate() {
    if (!_hapticsOn) return;
    if (!kIsWeb && Platform.isAndroid && _hasVibrator) {
      try {
        Vibration.vibrate(
          duration: 35,
          amplitude: _hasAmplitudeControl ? 160 : -1, // ~medium
        ).catchError((_) {
          // Fallback to standard Flutter haptics if native vibration fails
          HapticFeedback.mediumImpact();
        });
      } catch (_) {
        // Fallback for synchronous exceptions
        HapticFeedback.mediumImpact();
      }
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  PixelArt? get currentArt => _currentArt;
  List<List<int>> get filledGrid => _filledGrid;

  /// Monotonic counter bumped on every [filledGrid] mutation. Painters compare
  /// it in shouldRepaint so unrelated rebuilds don't repaint the whole grid.
  int get gridRevision => _gridRevision;
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
  bool get isStroking => _inStroke;
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
    _storageService.setString('${_saveKey}_timelapse', _serializeTimeLapse());
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

  /// Returns the serialized timelapse, appending only entries added since the
  /// last save. Any operation that shrinks or replaces [_timeLapse] calls
  /// [_invalidateTimeLapseCache] to force a one-time full rebuild.
  String _serializeTimeLapse() {
    if (_timeLapse.length < _timeLapseSerializedCount) {
      _invalidateTimeLapseCache();
    }
    if (_timeLapse.length > _timeLapseSerializedCount) {
      final sb = StringBuffer(_timeLapseSerialized);
      for (var i = _timeLapseSerializedCount; i < _timeLapse.length; i++) {
        if (sb.isNotEmpty) sb.write(';');
        final (r, c) = _timeLapse[i];
        sb
          ..write(r)
          ..write(',')
          ..write(c);
      }
      _timeLapseSerialized = sb.toString();
      _timeLapseSerializedCount = _timeLapse.length;
    }
    return _timeLapseSerialized;
  }

  void _invalidateTimeLapseCache() {
    _timeLapseSerialized = '';
    _timeLapseSerializedCount = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  // --- Frame-coalesced updates ---
  // The whole coloring screen listens to this provider, so notifying per filled
  // cell rebuilt the entire widget tree on every pointer move (drags fire
  // 100+/sec) and saturated the UI thread. Coalesce stroke updates to at most
  // one rebuild per frame.
  bool _disposed = false;
  bool _strokeFlushScheduled = false;

  void _scheduleStrokeFlush() {
    if (_strokeFlushScheduled) return;
    _strokeFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _strokeFlushScheduled = false;
      if (_disposed) return;
      // Progress and per-number tallies are updated incrementally as cells
      // change, so the flush only needs to trigger the rebuild.
      notifyListeners();
    });
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
    _gridRevision++;
    _totalFillCount = _storageService.getInt('${_saveKey}_fills');
    _totalEraseCount = _storageService.getInt('${_saveKey}_erases');
    _restoreTimeLapse();
    _restoreMilestones();
    // Progress/completion are computed by loadArt right after this returns.
  }

  /// Rebuilds the paint history from storage so Replay / Share GIF work on a
  /// reopened (e.g. already-completed) artwork. Tolerant of malformed entries.
  void _restoreTimeLapse() {
    _invalidateTimeLapseCache();
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
    _invalidateTimeLapseCache();
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
    _undoStack.clear();
    _currentUndoEntry = null;
    _fillCursor.clear();
    _gridRevision++;
    _timeLapse = [];
    _invalidateTimeLapseCache();
    _claimedMilestones = {};
    _consecutiveFills = 0;
    loadProgress();
    // Single full-grid pass for both the restored fills and the per-number
    // totals (loadProgress no longer runs its own duplicate pass).
    _calculateProgress();
    _isComplete = _progress >= AppConfig.completionThreshold &&
        _storageService.getString(_saveKey).isNotEmpty;
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
    final art = _currentArt;
    if (art == null) {
      _nextFillable = null;
      return;
    }
    // The tallies say nothing is left of this number — skip the scan.
    if (_totalPerNumber.isNotEmpty && !_hasUnfilled(_selectedNumber)) {
      _nextFillable = null;
      return;
    }
    final w = art.gridWidth;
    final total = w * art.gridHeight;
    var start = _fillCursor[_selectedNumber] ?? 0;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = start; i < total; i++) {
        if (art.grid[i ~/ w][i % w] == _selectedNumber &&
            _filledGrid[i ~/ w][i % w] == 0) {
          _fillCursor[_selectedNumber] = i;
          _nextFillable = (i ~/ w, i % w);
          return;
        }
      }
      // Cursor overshot (shouldn't happen — un-fill paths clear it); rescan
      // once from the top before concluding nothing is left.
      if (start == 0) break;
      start = 0;
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
      _beginUndoEntry();

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
          _writeCell(r, c, expectedNumber);
          _noteFill(expectedNumber);
          _timeLapse.add((r, c));
          anyFilled = true;
          onCellFilledCorrectly?.call();
          onCellFilledAt?.call(r, c);
        }
      }

      if (!anyFilled) {
        _abortUndoEntry();
        return false;
      }
      _commitUndoEntry();

      _fillVibrate();

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
    _beginUndoEntry();
    _inStroke = true;
    _strokeChanged = false;
    _strokeTimeLapseStart = _timeLapse.length;
    _strokeStartCompleted = _getCompletedNumbers();
  }

  /// Reverts an in-progress stroke, e.g. when a drag turns into a two-finger
  /// pinch and the painted cells should not stick.
  void cancelStroke() {
    if (!_inStroke) return;
    _inStroke = false;
    _applyUndoEntry(_undoStack.removeLast());
    _currentUndoEntry = null;
    _timeLapse.removeRange(_strokeTimeLapseStart, _timeLapse.length);
    _invalidateTimeLapseCache();
    _fillCursor.clear();
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
          final expected = _currentArt!.grid[r][c];
          _writeCell(r, c, 0);
          if (expected > 0) {
            _noteErase(expected);
            _fillCursor.remove(expected);
          }
          changed = true;
        } else {
          final expectedNumber = _currentArt!.grid[r][c];
          if (expectedNumber == 0) continue;
          if (_filledGrid[r][c] > 0) continue;
          if (expectedNumber != _selectedNumber) continue;
          _writeCell(r, c, expectedNumber);
          _noteFill(expectedNumber);
          _timeLapse.add((r, c));
          changed = true;
          onCellFilledCorrectly?.call();
          onCellFilledAt?.call(r, c);
        }
      }
    }
    if (changed) {
      _strokeChanged = true;
      _scheduleStrokeFlush();
    }
  }

  void endStroke() {
    if (!_inStroke) return;
    _inStroke = false;
    if (!_strokeChanged) {
      _abortUndoEntry();
      return;
    }
    _commitUndoEntry();
    // Snapshot from beginStroke: tallies update live during the stroke, so a
    // snapshot taken here could never detect a section completed mid-stroke.
    final previouslyCompleted = _strokeStartCompleted;
    if (_isEraseMode) {
      _totalEraseCount++;
      _consecutiveFills = 0;
      _isComplete = false;
    } else {
      _fillVibrate();
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
    _beginUndoEntry();
    _selectedNumber = number;
    _highlightedNumber = number;
    _writeCell(r, c, number);
    _noteFill(number);
    _commitUndoEntry();
    _timeLapse.add((r, c));
    _fillVibrate();
    _totalFillCount++;
    onCellFilledCorrectly?.call();
    onCellFilledAt?.call(r, c);
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

    _beginUndoEntry();
    final expected = _currentArt!.grid[row][col];
    _writeCell(row, col, 0);
    _commitUndoEntry();
    if (expected > 0) {
      _noteErase(expected);
      _fillCursor.remove(expected);
    }
    _totalEraseCount++;
    _consecutiveFills = 0;
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
    _beginUndoEntry();
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber &&
            _filledGrid[row][col] == 0) {
          _writeCell(row, col, _selectedNumber);
          _noteFill(_selectedNumber);
          _timeLapse.add((row, col));
          changed = true;
        }
      }
    }
    if (changed) {
      _commitUndoEntry();
      // One callback for the whole batch — a per-cell call would queue a
      // sound play for every filled cell of the mass fill.
      onCellFilledCorrectly?.call();
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
    } else {
      _abortUndoEntry();
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _applyUndoEntry(_undoStack.removeLast());
    _fillCursor.clear();
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
    _undoStack.clear();
    _currentUndoEntry = null;
    _timeLapse = [];
    _consecutiveFills = 0;
    _nextFillable = null;
    _fillCursor.clear();
    _gridRevision++;
    clearProgress();
    _calculateProgress();
    notifyListeners();
  }

  /// Opens a fresh undo entry that subsequent [_writeCell] calls record into.
  void _beginUndoEntry() {
    final entry = <int>[];
    _currentUndoEntry = entry;
    _undoStack.add(entry);
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);
  }

  void _commitUndoEntry() {
    _currentUndoEntry = null;
  }

  /// Discards the entry opened by [_beginUndoEntry] (action changed nothing).
  void _abortUndoEntry() {
    _undoStack.removeLast();
    _currentUndoEntry = null;
  }

  /// Reverts one undo entry (in reverse write order) against the live grid.
  void _applyUndoEntry(List<int> entry) {
    final w = _currentArt!.gridWidth;
    for (var i = entry.length - 2; i >= 0; i -= 2) {
      _filledGrid[entry[i] ~/ w][entry[i] % w] = entry[i + 1];
    }
    _gridRevision++;
  }

  /// Writes one cell, recording its previous value into the active undo entry
  /// and bumping the paint revision.
  void _writeCell(int r, int c, int value) {
    _currentUndoEntry?..add(r * _currentArt!.gridWidth + c)..add(_filledGrid[r][c]);
    _filledGrid[r][c] = value;
    _gridRevision++;
  }

  /// Incremental tally update for a newly filled cell of [n].
  void _noteFill(int n) {
    _filledCount++;
    _filledPerNumber[n] = (_filledPerNumber[n] ?? 0) + 1;
    _progress = _fillableTotal == 0 ? 1.0 : _filledCount / _fillableTotal;
  }

  /// Incremental tally update for an erased cell of [n].
  void _noteErase(int n) {
    _filledCount = max(0, _filledCount - 1);
    _filledPerNumber[n] = max(0, (_filledPerNumber[n] ?? 0) - 1);
    _progress = _fillableTotal == 0 ? 1.0 : _filledCount / _fillableTotal;
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
    _fillableTotal = total;
    _filledCount = filled;
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
      _gridRevision++;
    }
    notifyListeners();
  }

  List<List<int>> getGridState() {
    return _filledGrid.map((row) => List<int>.from(row)).toList();
  }

  void restoreGridState(List<List<int>> state) {
    _filledGrid = state.map((row) => List<int>.from(row)).toList();
    _gridRevision++;
    _fillCursor.clear();
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

    _beginUndoEntry();

    // Flood fill over flat cell indices: a head-pointer queue (removeAt(0)
    // shifts the whole list — O(n²) on big regions) and a byte visited mask
    // (a Set of records boxes every coordinate pair).
    final w = _currentArt!.gridWidth;
    final h = _currentArt!.gridHeight;
    final visited = Uint8List(w * h);
    final queue = <int>[row * w + col];
    var head = 0;
    bool changed = false;

    while (head < queue.length) {
      final idx = queue[head++];
      if (visited[idx] == 1) continue;
      visited[idx] = 1;
      final r = idx ~/ w;
      final c = idx % w;

      if (_currentArt!.grid[r][c] == targetNum && _filledGrid[r][c] == 0) {
        _writeCell(r, c, targetNum);
        _noteFill(targetNum);
        _timeLapse.add((r, c));
        changed = true;

        if (r + 1 < h) queue.add(idx + w);
        if (r > 0) queue.add(idx - w);
        if (c + 1 < w) queue.add(idx + 1);
        if (c > 0) queue.add(idx - 1);
      }
    }

    if (changed) {
      _commitUndoEntry();
      // One callback for the whole flood fill, not one per filled cell.
      onCellFilledCorrectly?.call();
      _magicWandsCount--;
      _isMagicWandMode = false;
      _totalFillCount++;
      _haptic(HapticFeedback.mediumImpact);
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      saveProgress();
      notifyListeners();
      return true;
    } else {
      _abortUndoEntry();
      return false;
    }
  }

  bool _tryBombFill(int row, int col) {
    if (_bombsCount <= 0) {
      _isBombMode = false;
      notifyListeners();
      return false;
    }

    _beginUndoEntry();

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
        _writeCell(r, c, expectedNumber);
        _noteFill(expectedNumber);
        _timeLapse.add((r, c));
        changed = true;
      }
    }

    if (changed) {
      _commitUndoEntry();
      onCellFilledCorrectly?.call();
      _bombsCount--;
      _isBombMode = false;
      _totalFillCount++;
      _haptic(HapticFeedback.mediumImpact);
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      saveProgress();
      notifyListeners();
      return true;
    } else {
      _abortUndoEntry();
      return false;
    }
  }
}
