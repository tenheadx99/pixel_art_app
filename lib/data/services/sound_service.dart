import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

class SoundService {
  final List<AudioPlayer> _players = [];
  // Last playback rate set on each pooled player, so a raised combo pitch is
  // corrected before the player is reused — never mid-note.
  final List<double> _playerRates = [];
  int _currentPlayerIndex = 0;
  bool _initialized = false;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (_initialized) return;
    try {
      for (int i = 0; i < 6; i++) {
        final player = AudioPlayer();
        _players.add(player);
        _playerRates.add(1.0);
      }
      _initialized = true;
      developer.log('SoundService initialized with audioplayers successfully', name: 'SoundService');
    } catch (e, stackTrace) {
      developer.log('SoundService initialization failed', name: 'SoundService', error: e, stackTrace: stackTrace);
    }
  }

  void playBubblePop() {
    _playAsset('audio/bubble_pop.wav');
  }

  void playLightClick() {
    _playAsset('audio/light_click.wav');
  }

  /// Soft low "nope" for a wrong-number tap. Skips the fill throttle so it is
  /// never swallowed by a pop played just before it.
  void playWrongTap() {
    _playAsset('audio/wrong_tap.wav', throttled: false);
  }

  /// Sparkly chime for combo thresholds; [rate] raises the pitch so each tier
  /// (x5, x10, x20...) sounds one step more triumphant.
  void playComboChime({double rate = 1.0}) {
    _playAsset('audio/combo_chime.wav', throttled: false, rate: rate);
  }

  void _playAsset(
    String path, {
    bool throttled = true,
    double rate = 1.0,
  }) async {
    if (!_initialized || _players.isEmpty) return;

    // Throttling: prevent playing sound more than once every 15ms
    if (throttled) {
      final now = DateTime.now();
      if (now.difference(_lastSoundTime).inMilliseconds < 15) return;
      _lastSoundTime = now;
    }

    final index = _currentPlayerIndex;
    final player = _players[index];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
    try {
      if (_playerRates[index] != rate) {
        await player.setPlaybackRate(rate);
        _playerRates[index] = rate;
      }
      // Modern audioplayers v6 uses AssetSource for files in assets/ directory
      await player.play(AssetSource(path));
    } catch (e) {
      developer.log('Error playing sound $path', name: 'SoundService', error: e);
    }
  }

  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
    _players.clear();
    _initialized = false;
  }
}
