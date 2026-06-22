import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

class SoundService {
  final List<AudioPlayer> _players = [];
  int _currentPlayerIndex = 0;
  bool _initialized = false;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (_initialized) return;
    try {
      for (int i = 0; i < 6; i++) {
        final player = AudioPlayer();
        _players.add(player);
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

  void _playAsset(String path) async {
    if (!_initialized || _players.isEmpty) return;
    
    // Throttling: prevent playing sound more than once every 15ms
    final now = DateTime.now();
    if (now.difference(_lastSoundTime).inMilliseconds < 15) return;
    _lastSoundTime = now;
    
    final player = _players[_currentPlayerIndex];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
    try {
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
