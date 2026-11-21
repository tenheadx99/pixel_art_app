import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;
import 'package:pixel_art_app/config/flavor.dart';

class SoundService {
  final List<AudioPlayer> _players = [];
  // Last playback rate set on each pooled player, so a raised combo pitch is
  // corrected before the player is reused — never mid-note.
  final List<double> _playerRates = [];
  int _currentPlayerIndex = 0;
  bool _initialized = false;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  AudioPlayer? _ambientPlayer;
  String _currentAmbientTrack = 'none';

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

  String get currentAmbientTrack => _currentAmbientTrack;

  Future<void> playAmbient(String trackKey) async {
    if (!_initialized) await init();
    if (_currentAmbientTrack == trackKey && _ambientPlayer != null) return;
    _currentAmbientTrack = trackKey;
    try {
      if (_ambientPlayer == null) {
        _ambientPlayer = AudioPlayer();
        await _ambientPlayer!.setReleaseMode(ReleaseMode.loop);
      }
      if (trackKey == 'none' || trackKey.isEmpty) {
        await _ambientPlayer!.stop();
        return;
      }
      final path = 'audio/$trackKey.wav';
      await _ambientPlayer!.play(AssetSource(path));
    } catch (e) {
      developer.log('Error playing ambient track $trackKey', name: 'SoundService', error: e);
    }
  }

  Future<void> stopAmbient() async {
    _currentAmbientTrack = 'none';
    try {
      await _ambientPlayer?.stop();
    } catch (_) {}
  }

  Future<void> setAmbientVolume(double volume) async {
    try {
      await _ambientPlayer?.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  static const List<double> _pentatonicRates = [
    1.0,      // C
    1.122,    // D (+2 semitones)
    1.260,    // E (+4 semitones)
    1.498,    // G (+7 semitones)
    1.682,    // A (+9 semitones)
    2.0,      // C' (+12 semitones)
    2.245,    // D' (+14 semitones)
    2.520,    // E' (+16 semitones)
  ];

  /// Plays tactile placement audio customized for each craft flavor with
  /// smooth pentatonic pitch ascension during rapid coloring streaks.
  void playFlavorTap({
    CellRenderStyle? style,
    String? userSoundType,
    int streak = 0,
  }) {
    final rate = (streak <= 0)
        ? 1.0
        : _pentatonicRates[(streak - 1) % _pentatonicRates.length];

    if (userSoundType == 'light_click') {
      _playAsset('audio/light_click.wav', rate: rate);
      return;
    } else if (userSoundType == 'bubble_pop' && style == null) {
      _playAsset('audio/bubble_pop.wav', rate: rate);
      return;
    }

    final path = switch (style) {
      CellRenderStyle.brick => 'audio/brick_snap.wav',
      CellRenderStyle.bead => 'audio/bead_click.wav',
      CellRenderStyle.sticker => 'audio/sticker_slap.wav',
      CellRenderStyle.glow => 'audio/glow_pop.wav',
      CellRenderStyle.mosaic => 'audio/mosaic_clink.wav',
      CellRenderStyle.quilt || CellRenderStyle.knit => 'audio/fabric_soft.wav',
      CellRenderStyle.gem => 'audio/light_click.wav',
      _ => 'audio/bubble_pop.wav',
    };

    _playAsset(path, rate: rate);
  }

  /// Triumphant ascending arpeggio chime chord when a color section is 100% completed.
  void playNumberClear() {
    _playAsset('audio/number_clear.wav', throttled: false);
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

    // Throttling: prevent playing sound more than once every 38ms (~26 clicks/sec max)
    // to avoid saturating platform channels and native audio buffers during fast continuous drags.
    if (throttled) {
      final now = DateTime.now();
      if (now.difference(_lastSoundTime).inMilliseconds < 38) return;
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
      try {
        player.dispose();
      } catch (_) {}
    }
    _players.clear();
    try {
      _ambientPlayer?.dispose();
    } catch (_) {}
    _ambientPlayer = null;
    _initialized = false;
  }
}
