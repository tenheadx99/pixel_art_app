import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';
import 'package:pixel_art_app/config/app_config.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/economy_config_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

class ColoringProvider extends ChangeNotifier {
  final LocalStorageService _storageService;

  PixelArt? _currentArt;
  List<List<int>> _filledGrid = [];
  Map<int, Color> _filledColors = {};
  int _selectedNumber = 1;
  double _progress = 0.0;
  bool _isComplete = false;
  // Undo entries are per-action diffs — (row, col, previousValue) — instead of
  // full grid snapshots: a snapshot per tap copied the whole grid (4k+ ints on
  // 64², 20 retained) and was the main per-tap allocation cost.
  final List<List<(int, int, int)>> _undoStack = [];
  List<(int, int, int)>? _pendingUndo;
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
  // Grid-wide tallies maintained incrementally by [_setCell]; rebuilt by the
  // full rescan in [_calculateProgress] on load/undo/restore.
  int _totalCellCount = 0;
  int _filledCellsCount = 0;

  VoidCallback? onCellFilledCorrectly;
  VoidCallback? onSectionCompleted;
  // Fired with the grid coords of a just-filled cell so the UI can spawn a
  // joyful fill effect there. Mass fills (wand/bomb/fill-all) skip this to
  // avoid flooding the effect layer.
  void Function(int row, int col)? onCellFilledAt;
  // Fired when a plain tap lands on a cell whose number isn't the selected
  // one, so the UI can give a gentle "not this one" nudge instead of silence.
  void Function(int row, int col)? onWrongTap;

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

  bool buyBombWithDiamonds(AppSettingsProvider appSettings) {
    final cost = EconomyConfigService().currentConfig.diamondCostBomb;
    if (appSettings.useDiamonds(cost)) {
      addBombs(1);
      _isBombMode = true;
      _isMagicWandMode = false;
      _isEraseMode = false;
      _haptic(HapticFeedback.selectionClick);
      notifyListeners();
      return true;
    }
    return false;
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

  /// Soft "nope" buzz for a wrong-number tap — clearly lighter than the fill
  /// buzz so right and wrong feel different.
  void _wrongTapVibrate() {
    if (!_hapticsOn) return;
    if (!kIsWeb && Platform.isAndroid && _hasVibrator) {
      try {
        Vibration.vibrate(
          duration: 20,
          amplitude: _hasAmplitudeControl ? 90 : -1,
        ).catchError((_) => HapticFeedback.lightImpact());
      } catch (_) {
        HapticFeedback.lightImpact();
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Escalating celebration buzz for combo tiers (0 = first threshold).
  void comboHaptic(int tier) {
    if (!_hapticsOn) return;
    if (!kIsWeb && Platform.isAndroid && _hasVibrator) {
      try {
        Vibration.vibrate(
          duration: 30 + tier * 10,
          amplitude:
              _hasAmplitudeControl ? (150 + tier * 25).clamp(1, 255) : -1,
        ).catchError((_) => HapticFeedback.heavyImpact());
      } catch (_) {
        HapticFeedback.heavyImpact();
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

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

  // Invalidates in-flight async saves; bumped whenever a newer save starts or
  // the saved-state lifecycle changes (clearProgress), so a slow encode can
  // never overwrite fresher data or resurrect cleared progress.
  int _saveSeq = 0;

  Future<void> saveProgress() async {
    if (_currentArt == null) return;
    final saveKey = _saveKey;
    // Cheap scalar writes stay synchronous.
    _storageService.setInt('${saveKey}_fills', _totalFillCount);
    _storageService.setInt('${saveKey}_erases', _totalEraseCount);
    _storageService.setString(
      '${saveKey}_milestones',
      _claimedMilestones.join(','),
    );
    // Lightweight percent so list screens can show progress without parsing
    // the full grid string.
    _storageService.setInt('${saveKey}_pct', (_progress * 100).round());
    _storageService.setString(_achieveKey, _achievements.join(','));
    _storageService.setInt(AppConstants.magicWandsPrefKey, _magicWandsCount);
    _storageService.setInt('bombs_count', _bombsCount);
    _storageService.setInt('brushes_count', _brushesCount);

    // The grid and time-lapse strings grow with artwork size (tens of KB on
    // large grids); building them blocked the UI thread on every debounced
    // save. Snapshot the state now, encode on a worker isolate, then write.
    final gridSnapshot = _filledGrid
        .map((row) => List<int>.of(row, growable: false))
        .toList(growable: false);
    final timeLapseSnapshot = List<(int, int)>.of(_timeLapse, growable: false);
    final seq = ++_saveSeq;
    final encoded = await compute(
      _encodeSaveStrings,
      (grid: gridSnapshot, timeLapse: timeLapseSnapshot),
    );
    if (seq != _saveSeq) return; // superseded by a newer save or a clear
    _storageService.setString(saveKey, encoded.grid);
    // Persist the paint history so Replay / Share GIF keep working when a
    // finished artwork is reopened later (the in-memory list is reset on load).
    _storageService.setString('${saveKey}_timelapse', encoded.timeLapse);
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(AppConfig.autoSaveDelay, saveProgress);
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
      // Counters are already fresh (updated per cell in _setCell); the flush
      // only needs to publish them once per frame.
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
    _saveSeq++; // drop any in-flight async save so it can't resurrect data
    _storageService.setString(_saveKey, '');
    _storageService.setInt('${_saveKey}_pct', 0);
    _storageService.setString('${_saveKey}_timelapse', '');
    _storageService.setString('${_saveKey}_milestones', '');
    _timeLapse = [];
    _claimedMilestones = {};
    _consecutiveFills = 0;
  }

  // --- Diff-based undo ---
  // An action opens an entry, every cell write records (row, col, prev) into
  // it via [_setCell], and the action either commits it to the stack or aborts
  // (optionally reverting the writes, e.g. a cancelled stroke).

  void _beginUndo() {
    _pendingUndo = [];
  }

  void _setCell(int row, int col, int value) {
    final prev = _filledGrid[row][col];
    _pendingUndo?.add((row, col, prev));
    _filledGrid[row][col] = value;
    _fillVersion++;
    // Keep progress counters in sync incrementally: a full-grid rescan per
    // fill (the old _calculateProgress-on-every-tap) was O(W×H) and the main
    // provider cost during fast swipes. Full rescans remain only on
    // load/undo/restore, where the grid changes wholesale.
    final expected = _currentArt?.grid[row][col] ?? 0;
    if (expected > 0) {
      if (prev == 0 && value > 0) {
        _filledCellsCount++;
        _filledPerNumber[expected] = (_filledPerNumber[expected] ?? 0) + 1;
      } else if (prev > 0 && value == 0) {
        _filledCellsCount--;
        _filledPerNumber[expected] = (_filledPerNumber[expected] ?? 1) - 1;
      }
    }
    _progress =
        _totalCellCount == 0 ? 1.0 : _filledCellsCount / _totalCellCount;
  }

  void _commitUndo() {
    final entry = _pendingUndo;
    _pendingUndo = null;
    if (entry == null || entry.isEmpty) return;
    _undoStack.add(entry);
    if (_undoStack.length > AppConfig.maxUndoSteps) _undoStack.removeAt(0);
  }

  void _abortUndo({bool revert = false}) {
    final entry = _pendingUndo;
    _pendingUndo = null;
    if (entry == null || !revert) return;
    for (final (row, col, prev) in entry.reversed) {
      _filledGrid[row][col] = prev;
    }
  }

  /// Caps the replay history: erase/refill cycles could otherwise grow it
  /// without bound (it is re-serialized on every save).
  static const int _maxTimeLapseEntries = 16384;

  void _recordTimeLapse(int row, int col) {
    if (_timeLapse.length < _maxTimeLapseEntries) _timeLapse.add((row, col));
  }

  /// Bumped whenever fill state changes; cheap repaint key for painters that
  /// receive the (mutated-in-place) grid by reference, e.g. the minimap.
  int _fillVersion = 0;
  int get fillVersion => _fillVersion;

  bool cellIsFilled(int row, int col) {
    if (row < 0 || row >= _filledGrid.length) return false;
    if (col < 0 || col >= _filledGrid[0].length) return false;
    return _filledGrid[row][col] > 0;
  }

  Color? cellFillColor(int row, int col) {
    if (!cellIsFilled(row, col)) return null;
    return _filledColors[_filledGrid[row][col]];
  }

  /// When the current artwork was loaded; feeds artwork_completed's duration.
  DateTime? _artStartedAt;

  void loadArt(PixelArt art) {
    _currentArt = art;
    _artStartedAt = DateTime.now();
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
    _pendingUndo = null;
    _timeLapse = [];
    _claimedMilestones = {};
    _consecutiveFills = 0;
    loadProgress();
    _calculateProgress();
    AnalyticsService().logArtworkSelected(
      artId: art.id,
      category: art.category,
      title: art.name,
    );
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
    // O(1) exit for the common case — the selected color has no cells left —
    // so exhausting a color doesn't pay for a futile full-grid scan per tap.
    if (!_hasUnfilled(_selectedNumber)) {
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
      _beginUndo();

      for (var dr = -half; dr <= half; dr++) {
        for (var dc = -half; dc <= half; dc++) {
          final r = row + dr;
          final c = col + dc;
          if (r < 0 || r >= _currentArt!.gridHeight) continue;
          if (c < 0 || c >= _currentArt!.gridWidth) continue;
          final expectedNumber = _currentArt!.grid[r][c];
          if (expectedNumber == 0) continue;
          if (_filledGrid[r][c] > 0) continue;
          // Number selection happens only in the palette: a tap on a cell of
          // a different number never switches colors — it falls through to
          // the wrong-tap nudge below.
          if (expectedNumber != _selectedNumber) continue;
          _setCell(r, c, expectedNumber);
          _recordTimeLapse(r, c);
          anyFilled = true;
          onCellFilledCorrectly?.call();
          onCellFilledAt?.call(r, c);
        }
      }

      if (!anyFilled) {
        _abortUndo();
        // A tap on an unfilled cell of the WRONG number deserves a gentle
        // nudge; taps on filled/empty cells stay silent.
        final expected = _currentArt!.grid[row][col];
        if (expected > 0 &&
            _filledGrid[row][col] == 0 &&
            expected != _selectedNumber) {
          _consecutiveFills = 0;
          _wrongTapVibrate();
          onWrongTap?.call(row, col);
        }
        return false;
      }
      _commitUndo();

      _fillVibrate();

      _totalFillCount++;
      _consecutiveFills++;
      if (_brushSize > 1) {
        if (_brushesCount > 0) {
          _brushesCount--;
          AnalyticsService()
              .logBoosterUsed(type: 'brush', remaining: _brushesCount);
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
    _beginUndo();
    _inStroke = true;
    _strokeChanged = false;
    _strokeTimeLapseStart = _timeLapse.length;
  }

  /// Reverts an in-progress stroke, e.g. when a drag turns into a two-finger
  /// pinch and the painted cells should not stick.
  void cancelStroke() {
    if (!_inStroke) return;
    _inStroke = false;
    _abortUndo(revert: true);
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
          _setCell(r, c, 0);
          changed = true;
        } else {
          final expectedNumber = _currentArt!.grid[r][c];
          if (expectedNumber == 0) continue;
          if (_filledGrid[r][c] > 0) continue;
          if (expectedNumber != _selectedNumber) continue;
          _setCell(r, c, expectedNumber);
          _recordTimeLapse(r, c);
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
      _abortUndo();
      return;
    }
    _commitUndo();
    final previouslyCompleted = _getCompletedNumbers();
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
          AnalyticsService()
              .logBoosterUsed(type: 'brush', remaining: _brushesCount);
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
    _beginUndo();
    _selectedNumber = number;
    _highlightedNumber = number;
    _setCell(r, c, number);
    _commitUndo();
    _recordTimeLapse(r, c);
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

    _beginUndo();
    _setCell(row, col, 0);
    _commitUndo();
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
    _beginUndo();
    for (var row = 0; row < _currentArt!.gridHeight; row++) {
      for (var col = 0; col < _currentArt!.gridWidth; col++) {
        if (_currentArt!.grid[row][col] == _selectedNumber &&
            _filledGrid[row][col] == 0) {
          _setCell(row, col, _selectedNumber);
          _recordTimeLapse(row, col);
          changed = true;
          onCellFilledCorrectly?.call();
        }
      }
    }
    if (!changed) {
      _abortUndo();
      return;
    }
    _commitUndo();
    {
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _debouncedSave();

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
    final entry = _undoStack.removeLast();
    int fillCount = 0;
    for (final (row, col, prev) in entry.reversed) {
      if (prev == 0 && _filledGrid[row][col] > 0) {
        fillCount++;
      }
      _filledGrid[row][col] = prev;
    }
    if (fillCount > 0 && _timeLapse.length >= fillCount) {
      _timeLapse.removeRange(_timeLapse.length - fillCount, _timeLapse.length);
    }
    _calculateProgress();
    _isComplete = false;
    _updateNextFillable();
    _debouncedSave();
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
    _pendingUndo = null;
    _timeLapse = [];
    _consecutiveFills = 0;
    _nextFillable = null;
    _fillVersion++;
    _filledPerNumber.clear();
    _filledCellsCount = 0;
    clearProgress();
    notifyListeners();
  }

  /// Full-rescan recompute of progress and per-number tallies. Only needed
  /// when the grid changes wholesale (load, undo, restore, cancelled stroke);
  /// ordinary fills/erases keep the same counters fresh incrementally in
  /// [_setCell], so the per-tap hot path never scans the grid.
  void _calculateProgress() {
    if (_currentArt == null) return;
    _fillVersion++;
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
    _totalCellCount = total;
    _filledCellsCount = filled;
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
      if (!_isComplete && _currentArt != null) {
        AnalyticsService().logArtworkCompleted(
          artId: _currentArt!.id,
          category: _currentArt!.category,
          durationSeconds: _artStartedAt == null
              ? null
              : DateTime.now().difference(_artStartedAt!).inSeconds,
        );
      }
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
    // Persist just the achievement set now (cheap); the full progress save
    // rides the debounce so an unlock never hitches mid-stroke.
    _storageService.setString(_achieveKey, _achievements.join(','));
    _debouncedSave();
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
      _fillVersion++;
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

    _beginUndo();

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
        _setCell(r, c, targetNum);
        _recordTimeLapse(r, c);
        changed = true;
        onCellFilledCorrectly?.call();

        queue.add((r + 1, c));
        queue.add((r - 1, c));
        queue.add((r, c + 1));
        queue.add((r, c - 1));
      }
    }

    if (changed) {
      _commitUndo();
      _magicWandsCount--;
      _isMagicWandMode = false;
      _totalFillCount++;
      AnalyticsService()
          .logBoosterUsed(type: 'magic_wand', remaining: _magicWandsCount);
      _haptic(HapticFeedback.mediumImpact);
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      _debouncedSave();
      notifyListeners();
      return true;
    } else {
      _abortUndo();
      return false;
    }
  }

  bool _tryBombFill(int row, int col) {
    if (_bombsCount <= 0) {
      _isBombMode = false;
      notifyListeners();
      return false;
    }

    _beginUndo();

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
        _setCell(r, c, expectedNumber);
        _recordTimeLapse(r, c);
        changed = true;
        onCellFilledCorrectly?.call();
      }
    }

    if (changed) {
      _commitUndo();
      _bombsCount--;
      _isBombMode = false;
      _totalFillCount++;
      AnalyticsService().logBoosterUsed(type: 'bomb', remaining: _bombsCount);
      _haptic(HapticFeedback.mediumImpact);
      _checkCompletion();
      _checkAchievements();
      _updateNextFillable();
      _autoAdvanceIfDone();
      _debouncedSave();
      notifyListeners();
      return true;
    } else {
      _abortUndo();
      return false;
    }
  }
}

/// Builds the persisted grid / time-lapse strings. Top-level so
/// [ColoringProvider.saveProgress] can run it on a worker isolate via
/// [compute]; the payload lists are snapshots, never live provider state.
({String grid, String timeLapse}) _encodeSaveStrings(
  ({List<List<int>> grid, List<(int, int)> timeLapse}) data,
) {
  return (
    grid: data.grid.map((row) => row.join(',')).join(';'),
    timeLapse: data.timeLapse.map((a) => '${a.$1},${a.$2}').join(';'),
  );
}
