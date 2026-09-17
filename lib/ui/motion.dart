import 'package:flutter/animation.dart';

/// Canonical motion spec for the app. Every new animation should pick its
/// duration and curve from here so the whole UI moves with one rhythm;
/// hardcoded values elsewhere are migrated opportunistically.
abstract final class Motion {
  /// Press feedback, toggles, small state changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard reveals, fades, chip/state transitions.
  static const Duration base = Duration(milliseconds: 250);

  /// Emphasis moments: sheets, celebration cards, count-ups.
  static const Duration emphasis = Duration(milliseconds: 400);

  /// Default curve for almost everything — fast start, gentle settle.
  static const Curve standard = Curves.easeOutCubic;

  /// Entrances that should land with a soft overshoot (cards, popups).
  static const Curve settle = Curves.easeOutBack;

  /// Reward beats only (badges, buy-pops) — bouncy, use sparingly.
  static const Curve reward = Curves.elasticOut;
}
