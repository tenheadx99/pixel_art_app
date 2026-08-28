import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/models/economy_config.dart';

class EconomyConfigService {
  static final EconomyConfigService _instance = EconomyConfigService._();
  factory EconomyConfigService() => _instance;
  EconomyConfigService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  EconomyConfig _currentConfig = EconomyConfig.defaults;
  EconomyConfig get currentConfig => _currentConfig;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (e) {
        developer.log('Error notifying economy config listener', error: e);
      }
    }
  }

  Future<void> initialize() async {
    final flavorId = currentFlavor.name;
    final docPath = 'pixel_art/$flavorId/config/economy';

    try {
      final snap = await _db.doc(docPath).get();
      if (snap.exists && snap.data() != null) {
        _currentConfig = EconomyConfig.fromMap(snap.data()!);
        developer.log('Fetched remote economy config for $flavorId: ${_currentConfig.diamondPacks.length} packs');
        _notifyListeners();
      }
    } catch (e) {
      developer.log('Failed to fetch initial economy config for $flavorId. Using defaults.', error: e);
    }

    // Realtime updates
    try {
      _db.doc(docPath).snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          _currentConfig = EconomyConfig.fromMap(snap.data()!);
          developer.log('Updated remote economy config for $flavorId');
          _notifyListeners();
        }
      }, onError: (e) {
        developer.log('Economy config snapshot error', error: e);
      });
    } catch (e) {
      developer.log('Failed to attach economy config snapshot listener', error: e);
    }
  }
}
