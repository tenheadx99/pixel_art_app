import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/flavor.dart';
import '../models/achievement_config.dart';

/// Singleton service managing dynamic achievements fetched from Firestore
/// with offline caching and stat evaluation.
class AchievementService {
  static final AchievementService _instance = AchievementService._();
  factory AchievementService() => _instance;
  AchievementService._();

  static const String achievementsStorageKey = 'pixelart_achievements';
  static const String _cacheKey = 'cached_achievements_config';

  FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ??= FirebaseFirestore.instance;

  AchievementsConfig _config = const AchievementsConfig(
    isEnabled: true,
    achievements: AchievementsConfig.defaultAchievements,
  );

  Set<String> _unlockedIds = {};
  final List<VoidCallback> _listeners = [];
  bool _initialized = false;

  AchievementsConfig get config => _config;
  bool get isEnabled => _config.isEnabled;
  List<AchievementItem> get achievements =>
      _config.achievements.where((a) => a.isEnabled).toList();
  Set<String> get unlockedIds => Set.unmodifiable(_unlockedIds);

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final l in List.of(_listeners)) {
      try {
        l();
      } catch (e) {
        developer.log('AchievementService listener error: $e');
      }
    }
  }

  bool isUnlocked(String id) => _unlockedIds.contains(id);

  /// Initializes the service: loads local state & cache, then hooks Firestore real-time listener.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(achievementsStorageKey) ?? '';
      if (savedStr.isNotEmpty) {
        _unlockedIds = savedStr.split(',').where((s) => s.isNotEmpty).toSet();
      }

      // Load cached remote config if available
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map<String, dynamic>) {
          _config = AchievementsConfig.fromMap(decoded);
        }
      }
    } catch (e) {
      developer.log('Failed to load local achievements cache: $e');
    }

    // Connect to Firestore
    final flavorId = currentFlavor.name;
    final docPath = 'pixel_art/$flavorId/config/achievements';

    try {
      final snap = await _db.doc(docPath).get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.data() != null) {
        _applyRemoteConfig(snap.data()!);
      }
    } catch (e) {
      developer.log('Initial fetch for achievements config failed. Using defaults/cache: $e');
    }

    try {
      _db.doc(docPath).snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          _applyRemoteConfig(snap.data()!);
        }
      }, onError: (e) {
        developer.log('Achievements snapshot error: $e');
      });
    } catch (e) {
      developer.log('Failed to attach achievements snapshot listener: $e');
    }
  }

  void _applyRemoteConfig(Map<String, dynamic> data) async {
    try {
      _config = AchievementsConfig.fromMap(data);
      _notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_config.toMap()));
    } catch (e) {
      developer.log('Failed to apply achievements config: $e');
    }
  }

  /// Marks an achievement as unlocked, persists it to storage, and notifies listeners.
  /// Returns true if newly unlocked.
  Future<bool> unlock(String id) async {
    if (_unlockedIds.contains(id)) return false;
    _unlockedIds.add(id);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(achievementsStorageKey, _unlockedIds.join(','));
    } catch (e) {
      developer.log('Failed to persist unlocked achievement $id: $e');
    }

    _notifyListeners();
    return true;
  }

  /// Evaluates all enabled achievements against the provided player metrics.
  /// Unlocks newly qualifying achievements and returns the list of newly unlocked items.
  Future<List<AchievementItem>> evaluateStats({
    required int completedArts,
    required int dailyStreak,
    required int playerLevel,
    required int bombsUsed,
    required int wandsUsed,
    required int customArtsCreated,
    int? singleSessionFills,
    int? comboStreak,
    int? erasersUsed,
  }) async {
    if (!_config.isEnabled) return [];

    final newlyUnlocked = <AchievementItem>[];

    for (final item in achievements) {
      if (_unlockedIds.contains(item.id)) continue;

      bool qualifies = false;
      switch (item.metricType) {
        case 'completed_arts':
          qualifies = completedArts >= item.targetValue;
          break;
        case 'daily_streak':
          qualifies = dailyStreak >= item.targetValue;
          break;
        case 'player_level':
          qualifies = playerLevel >= item.targetValue;
          break;
        case 'bombs_used':
          qualifies = bombsUsed >= item.targetValue;
          break;
        case 'wands_used':
          qualifies = wandsUsed >= item.targetValue;
          break;
        case 'custom_arts_created':
          qualifies = customArtsCreated >= item.targetValue;
          break;
        case 'single_session_fills':
          if (singleSessionFills != null) {
            qualifies = singleSessionFills >= item.targetValue;
          }
          break;
        case 'combo_streak':
          if (comboStreak != null) {
            qualifies = comboStreak >= item.targetValue;
          }
          break;
        case 'erasers_used':
          if (erasersUsed != null) {
            qualifies = erasersUsed >= item.targetValue;
          }
          break;
      }

      if (qualifies) {
        final success = await unlock(item.id);
        if (success) {
          newlyUnlocked.add(item);
        }
      }
    }

    return newlyUnlocked;
  }

  /// Calculates the player's progress fraction [0.0 - 1.0] and current value towards an achievement.
  ({int current, int target, double progress}) getProgressForItem(
    AchievementItem item, {
    required int completedArts,
    required int dailyStreak,
    required int playerLevel,
    required int bombsUsed,
    required int wandsUsed,
    required int customArtsCreated,
  }) {
    if (isUnlocked(item.id)) {
      return (current: item.targetValue, target: item.targetValue, progress: 1.0);
    }

    int current = 0;
    switch (item.metricType) {
      case 'completed_arts':
        current = completedArts;
        break;
      case 'daily_streak':
        current = dailyStreak;
        break;
      case 'player_level':
        current = playerLevel;
        break;
      case 'bombs_used':
        current = bombsUsed;
        break;
      case 'wands_used':
        current = wandsUsed;
        break;
      case 'custom_arts_created':
        current = customArtsCreated;
        break;
      default:
        current = 0;
    }

    final target = item.targetValue;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return (current: current.clamp(0, target), target: target, progress: progress);
  }
}

