import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

/// Tracks cells that are mid "grow-in" so [PixelGrid]'s painter can scale the
/// colour up from the preview instead of snapping. Acts as the painter's
/// repaint [Listenable]: an external ticker calls [handleTick] each frame while
/// any cell is animating, which prunes finished cells and notifies a repaint.
///
/// Kept tiny on purpose — only tap/hint fills register here (strokes snap), and
/// the registry is capped — so per-cell `factor()` lookups during paint stay
/// cheap even on 64x64 grids.
class FillGrowController extends ChangeNotifier {
  final int gridWidth;
  final Map<int, int> _startMs = {};

  FillGrowController(this.gridWidth);

  static const int _durationMs = AppConstants.fillGrowMs;

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

  /// Called by the driving ticker each frame: drop finished cells and repaint.
  void handleTick(int nowMs) {
    _startMs.removeWhere((_, start) => nowMs - start >= _durationMs);
    notifyListeners();
  }

  void clear() {
    _startMs.clear();
  }
}
