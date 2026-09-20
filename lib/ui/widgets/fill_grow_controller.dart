import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../providers/coloring_provider.dart' show WaveFillType;

class _PendingRing {
  final int ringIndex;
  final int totalRings;
  final int startMs;
  final List<(int, int)> cells;

  _PendingRing({
    required this.ringIndex,
    required this.totalRings,
    required this.startMs,
    required this.cells,
  });
}

/// Tracks recently filled cells and their fill timestamps. Two consumers:
/// the flat-flavor painter scales cells in via [factor], and the gem shader
/// bakes the timestamps into a per-cell age texture that drives its
/// settle-pop / glint / afterglow timeline (swipes get a wave stagger from
/// the natural spread of stroke fill times, and bomb/fill waves get staggered
/// concentric and topological ripples). Acts as the painter's repaint
/// [Listenable]: an external ticker calls [handleTick] each frame while any
/// cell is animating, which prunes finished cells and notifies a repaint.
class FillGrowController extends ChangeNotifier {
  final int gridWidth;
  final Map<int, int> _startMs = {};
  final List<_PendingRing> _pendingRings = [];
  WaveFillType? activeWaveType;

  FillGrowController(this.gridWidth);

  static const int _durationMs = AppConstants.fillGrowMs;
  static const int _retentionMs = AppConstants.fillGrowRetentionMs;

  /// Fires on the tick in which any growing cell reaches full size (factor
  /// 1.0). The flat-flavor BASE layer listens to this — plus ordinary fill
  /// notifies — instead of the every-frame [notifyListeners] ticks, so it
  /// repaints only when a cell's settled appearance actually changes.
  Listenable get settled => _settled;
  final _SettleNotifier _settled = _SettleNotifier();

  /// Fires whenever a scheduled wave ring unlocks, alerting the gem texture baker
  /// and any synchronized audio/haptic effects.
  Listenable get newlyRevealed => _newlyRevealed;
  final _SettleNotifier _newlyRevealed = _SettleNotifier();

  /// Fired as each wave ring activates during an expanding wave animation.
  void Function(int ringIndex, List<(int r, int c)> cells, int totalRings)?
      onRingRevealed;

  int? _lastTickMs;

  @override
  void dispose() {
    _settled.dispose();
    _newlyRevealed.dispose();
    super.dispose();
  }

  int _key(int row, int col) => row * gridWidth + col;

  /// Registers a freshly-filled cell to animate in from [nowMs].
  void add(int row, int col, int nowMs) {
    if (_startMs.length >= AppConstants.fillGrowMaxCells) {
      // Drop the oldest so an unbounded burst can't grow indefinitely.
      final oldestKey = _startMs.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      _startMs.remove(oldestKey);
    }
    _startMs[_key(row, col)] = nowMs;
  }

  /// Schedules wave rings (from Bomb shockwave or Magic Wand flood)
  /// starting at [startMs] with staggered delays per ring.
  void addWave(
    List<List<(int r, int c)>> rings,
    int startMs, {
    int ringDelayMs = AppConstants.bombWaveRingDelayMs,
    WaveFillType? type,
  }) {
    activeWaveType = type;
    final totalRings = rings.length;
    for (var i = 0; i < totalRings; i++) {
      final ringTime = startMs + i * ringDelayMs;
      final ringCells = rings[i];
      for (final (r, c) in ringCells) {
        _startMs[_key(r, c)] = ringTime;
      }
      _pendingRings.add(_PendingRing(
        ringIndex: i,
        totalRings: totalRings,
        startMs: ringTime,
        cells: ringCells,
      ));
    }
    notifyListeners();
  }

  /// True if the cell's wave has arrived and it is ready to be drawn as filled.
  /// If [row, col] is not in an active wave schedule, returns true.
  bool isRevealed(int row, int col, int nowMs) {
    final start = _startMs[_key(row, col)];
    if (start == null) return true;
    return nowMs >= start;
  }

  /// Intensity of the subtle wavefront crest (fading to 0.0 over 110ms).
  double crestGlow(int row, int col, int nowMs) {
    final start = _startMs[_key(row, col)];
    if (start == null) return 0.0;
    final age = nowMs - start;
    if (age < 0 || age >= 110) return 0.0;
    final t = age / 110.0;
    return (1.0 - t) * (1.0 - t);
  }

  /// 0 = just placed / waiting for wave, 1 = fully grown. Returns 1 for cells that
  /// aren't animating, so callers can use it unconditionally.
  double factor(int row, int col, int nowMs) {
    final start = _startMs[_key(row, col)];
    if (start == null) return 1.0;
    final age = nowMs - start;
    if (age < 0) return 0.0;
    if (age >= _durationMs) return 1.0;
    return Curves.easeOutBack.transform((age / _durationMs).clamp(0.0, 1.0));
  }

  bool get isEmpty => _startMs.isEmpty && _pendingRings.isEmpty;

  /// True while a wave animation is currently scheduled or expanding.
  bool get isWaveActive => activeWaveType != null || _pendingRings.isNotEmpty;

  /// The fill timestamp of a still-registered cell, or null once it has been
  /// pruned. Lets the flat-flavor painter run its afterglow directly off the
  /// same clock the grow uses.
  int? startMsOf(int row, int col) => _startMs[_key(row, col)];

  /// Visits every registered cell with its fill timestamp; used to bake the
  /// gem shader's per-cell age texture.
  void forEachActive(void Function(int row, int col, int startMs) visit) {
    _startMs.forEach((key, startMs) {
      visit(key ~/ gridWidth, key % gridWidth, startMs);
    });
  }

  /// Called by the driving ticker each frame: drop finished cells and repaint.
  /// Cells are retained past the flat grow so the shader timeline (glint,
  /// afterglow) keeps its timing source until it finishes.
  void handleTick(int nowMs) {
    final last = _lastTickMs;
    _lastTickMs = nowMs;

    // Check newly revealed wave rings
    if (_pendingRings.isNotEmpty) {
      final unlocked = <_PendingRing>[];
      _pendingRings.removeWhere((item) {
        if (nowMs >= item.startMs) {
          unlocked.add(item);
          return true;
        }
        return false;
      });
      for (final ring in unlocked) {
        onRingRevealed?.call(ring.ringIndex, ring.cells, ring.totalRings);
      }
      if (unlocked.isNotEmpty) {
        _newlyRevealed.fire();
      }
    }

    var anySettled = false;
    for (final start in _startMs.values) {
      // Settled this tick: grow just finished, but it hadn't as of last tick.
      if (nowMs - start >= _durationMs &&
          (last == null || last - start < _durationMs)) {
        anySettled = true;
        break;
      }
    }
    _startMs.removeWhere((_, start) => nowMs - start >= _retentionMs);
    if (_startMs.isEmpty && _pendingRings.isEmpty) {
      activeWaveType = null;
    }
    if (anySettled) _settled.fire();
    notifyListeners();
  }

  void clear() {
    _startMs.clear();
    _pendingRings.clear();
    activeWaveType = null;
  }
}

class _SettleNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}
