import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

/// Tracks recently filled cells and their fill timestamps. Two consumers:
/// the flat-flavor painter scales cells in via [factor], and the gem shader
/// bakes the timestamps into a per-cell age texture that drives its
/// settle-pop / glint / afterglow timeline (swipes get a wave stagger from
/// the natural spread of stroke fill times). Acts as the painter's repaint
/// [Listenable]: an external ticker calls [handleTick] each frame while any
/// cell is animating, which prunes finished cells and notifies a repaint.
///
/// Kept tiny on purpose — the registry is capped — so per-cell `factor()`
/// lookups during paint stay cheap even on 64x64 grids.
class FillGrowController extends ChangeNotifier {
  final int gridWidth;
  final Map<int, int> _startMs = {};

  FillGrowController(this.gridWidth);

  static const int _durationMs = AppConstants.fillGrowMs;
  static const int _retentionMs = AppConstants.fillGrowRetentionMs;

  /// Fires on the tick in which any growing cell reaches full size (factor
  /// 1.0). The flat-flavor BASE layer listens to this — plus ordinary fill
  /// notifies — instead of the every-frame [notifyListeners] ticks, so it
  /// repaints only when a cell's settled appearance actually changes.
  Listenable get settled => _settled;
  final _SettleNotifier _settled = _SettleNotifier();
  int? _lastTickMs;

  @override
  void dispose() {
    _settled.dispose();
    super.dispose();
  }

  int _key(int row, int col) => row * gridWidth + col;

  /// Registers a freshly-filled cell to animate in from [nowMs].
  void add(int row, int col, int nowMs) {
    if (_startMs.length >= AppConstants.fillGrowMaxCells) {
      // Drop the oldest so a burst (e.g. 3x3 brush) can't grow unbounded.
      final oldestKey = _startMs.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      _startMs.remove(oldestKey);
    }
    _startMs[_key(row, col)] = nowMs;
  }

  /// 0 = just placed (smallest), 1 = fully grown. Returns 1 for cells that
  /// aren't animating, so callers can use it unconditionally.
  double factor(int row, int col, int nowMs) {
    final start = _startMs[_key(row, col)];
    if (start == null) return 1.0;
    final age = nowMs - start;
    if (age >= _durationMs) return 1.0;
    return Curves.easeOutCubic.transform((age / _durationMs).clamp(0.0, 1.0));
  }

  bool get isEmpty => _startMs.isEmpty;

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
    if (anySettled) _settled.fire();
    notifyListeners();
  }

  void clear() {
    _startMs.clear();
  }
}

class _SettleNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}
