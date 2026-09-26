import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_constants.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import 'local_storage_service.dart';

class CloudSyncResult {
  final bool success;
  final int diamonds;
  final int completedArtsCount;
  final int unlockedArtsCount;
  final DateTime syncedAt;
  final String? error;

  const CloudSyncResult({
    required this.success,
    required this.diamonds,
    required this.completedArtsCount,
    required this.unlockedArtsCount,
    required this.syncedAt,
    this.error,
  });
}

/// Cloud sync engine that reconciles local game progress (SharedPreferences)
/// with the user's remote Firestore profile at `users/{userId}`.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._();
  factory CloudSyncService() => _instance;
  CloudSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection('users').doc(userId);
  }

  /// Syncs local state with Firestore.
  /// Resolves conflicts using a union/maximum strategy so player progress is never wiped.
  Future<CloudSyncResult> syncUserData({
    required String userId,
    required LocalStorageService storage,
    AppSettingsProvider? settingsProvider,
    GalleryProvider? galleryProvider,
  }) async {
    try {
      final docRef = _userDoc(userId);
      final snapshot = await docRef.get();

      // Read local state
      final localDiamonds = storage.getInt('diamonds_available', defaultValue: 50);
      final localXp = storage.getInt('player_xp', defaultValue: 0);
      final localLevel = storage.getInt('player_level', defaultValue: 1);
      final localHints = storage.getInt(AppConstants.hintsPrefKey, defaultValue: 3);
      final localWands = storage.getInt(AppConstants.magicWandsPrefKey, defaultValue: 2);
      final localStreak = storage.getInt('daily_streak_count', defaultValue: 0);
      final localCompleted = storage.getStringSet(AppConstants.completedIdsPrefKey);
      final localUnlocked = storage.getStringSet('diamond_unlocked_ids');

      if (!snapshot.exists || snapshot.data() == null) {
        // First sync: Upload local progress to cloud
        final data = {
          'diamonds': localDiamonds,
          'xp': localXp,
          'level': localLevel,
          'hints': localHints,
          'wands': localWands,
          'dailyStreak': localStreak,
          'completedArtworks': localCompleted.toList(),
          'unlockedArtworks': localUnlocked.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await docRef.set(data, SetOptions(merge: true));
        developer.log('Initial cloud sync complete for user $userId', name: 'CloudSync');

        return CloudSyncResult(
          success: true,
          diamonds: localDiamonds,
          completedArtsCount: localCompleted.length,
          unlockedArtsCount: localUnlocked.length,
          syncedAt: DateTime.now(),
        );
      }

      // Existing remote data: Merge intelligently
      final remote = snapshot.data()!;
      final remoteDiamonds = (remote['diamonds'] as num?)?.toInt() ?? 0;
      final remoteXp = (remote['xp'] as num?)?.toInt() ?? 0;
      final remoteLevel = (remote['level'] as num?)?.toInt() ?? 1;
      final remoteHints = (remote['hints'] as num?)?.toInt() ?? 0;
      final remoteWands = (remote['wands'] as num?)?.toInt() ?? 0;
      final remoteStreak = (remote['dailyStreak'] as num?)?.toInt() ?? 0;
      final remoteCompletedList = List<String>.from(remote['completedArtworks'] ?? const []);
      final remoteUnlockedList = List<String>.from(remote['unlockedArtworks'] ?? const []);

      final mergedDiamonds = max(localDiamonds, remoteDiamonds);
      final mergedXp = max(localXp, remoteXp);
      final mergedLevel = max(localLevel, remoteLevel);
      final mergedHints = max(localHints, remoteHints);
      final mergedWands = max(localWands, remoteWands);
      final mergedStreak = max(localStreak, remoteStreak);
      final mergedCompleted = {...localCompleted, ...remoteCompletedList};
      final mergedUnlocked = {...localUnlocked, ...remoteUnlockedList};

      // Write merged state to local storage
      storage.setInt('diamonds_available', mergedDiamonds);
      storage.setInt('player_xp', mergedXp);
      storage.setInt('player_level', mergedLevel);
      storage.setInt(AppConstants.hintsPrefKey, mergedHints);
      storage.setInt(AppConstants.magicWandsPrefKey, mergedWands);
      storage.setInt('daily_streak_count', mergedStreak);
      storage.setStringList(AppConstants.completedIdsPrefKey, mergedCompleted.toList());
      storage.setStringList('diamond_unlocked_ids', mergedUnlocked.toList());

      // Update in-memory providers if provided
      if (settingsProvider != null) {
        settingsProvider.reloadEconomy();
      }
      if (galleryProvider != null) {
        galleryProvider.reloadUnlockedPieces();
      }

      // Write merged state back to Firestore
      await docRef.set({
        'diamonds': mergedDiamonds,
        'xp': mergedXp,
        'level': mergedLevel,
        'hints': mergedHints,
        'wands': mergedWands,
        'dailyStreak': mergedStreak,
        'completedArtworks': mergedCompleted.toList(),
        'unlockedArtworks': mergedUnlocked.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('Cloud sync reconciled for user $userId (diamonds: $mergedDiamonds, completed: ${mergedCompleted.length})', name: 'CloudSync');

      return CloudSyncResult(
        success: true,
        diamonds: mergedDiamonds,
        completedArtsCount: mergedCompleted.length,
        unlockedArtsCount: mergedUnlocked.length,
        syncedAt: DateTime.now(),
      );
    } catch (e, st) {
      developer.log('Cloud sync error for user $userId', name: 'CloudSync', error: e, stackTrace: st);
      return CloudSyncResult(
        success: false,
        diamonds: storage.getInt('diamonds_available', defaultValue: 50),
        completedArtsCount: storage.getStringSet(AppConstants.completedIdsPrefKey).length,
        unlockedArtsCount: storage.getStringSet('diamond_unlocked_ids').length,
        syncedAt: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Cleans up remote data when a user deletes their account.
  Future<void> deleteUserData(String userId) async {
    try {
      await _userDoc(userId).delete();
      developer.log('Deleted cloud user data for $userId', name: 'CloudSync');
    } catch (e) {
      developer.log('Failed to delete cloud data for $userId', name: 'CloudSync', error: e);
    }
  }
}
