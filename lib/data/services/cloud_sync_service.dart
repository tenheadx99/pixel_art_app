import 'dart:developer' as developer;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_constants.dart';
import '../../config/flavor.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import 'local_storage_service.dart';

class CloudSyncResult {
  final bool success;
  final int diamonds;
  final int completedArtsCount;
  final int unlockedArtsCount;
  final int favoriteArtsCount;
  final bool isPro;
  final DateTime syncedAt;
  final String? error;

  const CloudSyncResult({
    required this.success,
    required this.diamonds,
    required this.completedArtsCount,
    required this.unlockedArtsCount,
    this.favoriteArtsCount = 0,
    this.isPro = false,
    required this.syncedAt,
    this.error,
  });
}

/// Cloud sync engine that reconciles local game progress (SharedPreferences)
/// with the user's remote Firestore profile at `{appPrefix}_users/{userId}`.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._();
  factory CloudSyncService() => _instance;
  CloudSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Normalized prefix derived from the app name (e.g. "pixely", "divine_pixels", "anime_pixels").
  static String get appPrefix {
    return FlavorConfig.current.appName.toLowerCase().replaceAll(' ', '_');
  }

  /// App-specific collection name, e.g. "pixely_users", "divine_pixels_users", "anime_pixels_users".
  static String get usersCollection {
    return '${appPrefix}_users';
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(usersCollection).doc(userId);
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
      var snapshot = await docRef.get();

      // Backward compatibility: If doc does not exist in {appPrefix}_users yet,
      // check if it was previously saved under users/{appPrefix}_{userId} or users/{userId}.
      if (!snapshot.exists || snapshot.data() == null) {
        final legacyPrefixedDoc = _db.collection('users').doc('${appPrefix}_$userId');
        final legacyPrefixedSnap = await legacyPrefixedDoc.get();
        if (legacyPrefixedSnap.exists && legacyPrefixedSnap.data() != null) {
          snapshot = legacyPrefixedSnap;
        } else {
          final legacyDocRef = _db.collection('users').doc(userId);
          final legacySnapshot = await legacyDocRef.get();
          if (legacySnapshot.exists && legacySnapshot.data() != null) {
            snapshot = legacySnapshot;
          }
        }
      }

      // Read local state
      final localDiamonds = storage.getInt('diamonds_available', defaultValue: 50);
      final localXp = storage.getInt('player_xp', defaultValue: 0);
      final localLevel = storage.getInt('player_level', defaultValue: 1);
      final localHints = storage.getInt(AppConstants.hintsPrefKey, defaultValue: 3);
      final localWands = storage.getInt(AppConstants.magicWandsPrefKey, defaultValue: 2);
      final localStreak = storage.getInt('daily_streak_count', defaultValue: 0);
      final localCompleted = storage.getStringSet(AppConstants.completedIdsPrefKey);
      final localUnlocked = storage.getStringSet('diamond_unlocked_ids');
      final localFavorites = storage.getStringSet('favorite_ids');
      final localPro = storage.getBool(AppConstants.proPrefKey);
      final localRemoveAds = storage.getBool(AppConstants.removeAdsPrefKey);
      final localPlusExpiry = storage.getInt(AppConstants.plusExpiryPrefKey);

      if (!snapshot.exists || snapshot.data() == null) {
        // First sync: Upload local progress and purchase entitlements to cloud
        final data = {
          'appId': appPrefix,
          'appName': FlavorConfig.current.appName,
          'flavor': currentFlavor.name,
          'userId': userId,
          'diamonds': localDiamonds,
          'xp': localXp,
          'level': localLevel,
          'hints': localHints,
          'wands': localWands,
          'dailyStreak': localStreak,
          'completedArtworks': localCompleted.toList(),
          'unlockedArtworks': localUnlocked.toList(),
          'favoriteArtworks': localFavorites.toList(),
          'isPro': localPro,
          'isRemoveAds': localRemoveAds,
          'plusExpiry': localPlusExpiry,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await docRef.set(data, SetOptions(merge: true));
        developer.log('Initial cloud sync complete for $usersCollection/$userId', name: 'CloudSync');

        return CloudSyncResult(
          success: true,
          diamonds: localDiamonds,
          completedArtsCount: localCompleted.length,
          unlockedArtsCount: localUnlocked.length,
          favoriteArtsCount: localFavorites.length,
          isPro: localPro,
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
      final remoteFavoritesList = List<String>.from(remote['favoriteArtworks'] ?? const []);
      final remotePro = (remote['isPro'] as bool?) ?? false;
      final remoteRemoveAds = (remote['isRemoveAds'] as bool?) ?? false;
      final remotePlusExpiry = (remote['plusExpiry'] as num?)?.toInt() ?? 0;

      final mergedDiamonds = max(localDiamonds, remoteDiamonds);
      final mergedXp = max(localXp, remoteXp);
      final mergedLevel = max(localLevel, remoteLevel);
      final mergedHints = max(localHints, remoteHints);
      final mergedWands = max(localWands, remoteWands);
      final mergedStreak = max(localStreak, remoteStreak);
      final mergedCompleted = {...localCompleted, ...remoteCompletedList};
      final mergedUnlocked = {...localUnlocked, ...remoteUnlockedList};
      final mergedFavorites = {...localFavorites, ...remoteFavoritesList};
      final mergedPro = localPro || remotePro;
      final mergedRemoveAds = localRemoveAds || remoteRemoveAds;
      final mergedPlusExpiry = max(localPlusExpiry, remotePlusExpiry);

      // Write merged state to local storage
      storage.setInt('diamonds_available', mergedDiamonds);
      storage.setInt('player_xp', mergedXp);
      storage.setInt('player_level', mergedLevel);
      storage.setInt(AppConstants.hintsPrefKey, mergedHints);
      storage.setInt(AppConstants.magicWandsPrefKey, mergedWands);
      storage.setInt('daily_streak_count', mergedStreak);
      storage.setStringList(AppConstants.completedIdsPrefKey, mergedCompleted.toList());
      storage.setStringList('diamond_unlocked_ids', mergedUnlocked.toList());
      storage.setStringList('favorite_ids', mergedFavorites.toList());
      storage.setBool(AppConstants.proPrefKey, mergedPro);
      storage.setBool(AppConstants.removeAdsPrefKey, mergedRemoveAds);
      storage.setInt(AppConstants.plusExpiryPrefKey, mergedPlusExpiry);

      // Update in-memory providers if provided
      if (settingsProvider != null) {
        settingsProvider.reloadEconomy();
      }
      if (galleryProvider != null) {
        galleryProvider.reloadCloudState();
      }

      // Write merged state back to Firestore
      await docRef.set({
        'appId': appPrefix,
        'appName': FlavorConfig.current.appName,
        'flavor': currentFlavor.name,
        'userId': userId,
        'diamonds': mergedDiamonds,
        'xp': mergedXp,
        'level': mergedLevel,
        'hints': mergedHints,
        'wands': mergedWands,
        'dailyStreak': mergedStreak,
        'completedArtworks': mergedCompleted.toList(),
        'unlockedArtworks': mergedUnlocked.toList(),
        'favoriteArtworks': mergedFavorites.toList(),
        'isPro': mergedPro,
        'isRemoveAds': mergedRemoveAds,
        'plusExpiry': mergedPlusExpiry,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('Cloud sync reconciled for $usersCollection/$userId (diamonds: $mergedDiamonds, completed: ${mergedCompleted.length}, pro: $mergedPro)', name: 'CloudSync');

      return CloudSyncResult(
        success: true,
        diamonds: mergedDiamonds,
        completedArtsCount: mergedCompleted.length,
        unlockedArtsCount: mergedUnlocked.length,
        favoriteArtsCount: mergedFavorites.length,
        isPro: mergedPro,
        syncedAt: DateTime.now(),
      );
    } catch (e, st) {
      developer.log('Cloud sync error for user $userId', name: 'CloudSync', error: e, stackTrace: st);
      return CloudSyncResult(
        success: false,
        diamonds: storage.getInt('diamonds_available', defaultValue: 50),
        completedArtsCount: storage.getStringSet(AppConstants.completedIdsPrefKey).length,
        unlockedArtsCount: storage.getStringSet('diamond_unlocked_ids').length,
        favoriteArtsCount: storage.getStringSet('favorite_ids').length,
        isPro: storage.getBool(AppConstants.proPrefKey),
        syncedAt: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Records a purchase transaction in Firestore under `{appPrefix}_users/{userId}/purchases/{docId}`.
  Future<void> logPurchaseTransaction({
    required String userId,
    required String productId,
    String? orderId,
    String? status,
    int? quantity,
  }) async {
    try {
      final now = DateTime.now();
      final docId = (orderId != null && orderId.trim().isNotEmpty)
          ? orderId.replaceAll('/', '_').replaceAll(':', '_')
          : '${productId}_${now.millisecondsSinceEpoch}';

      await _userDoc(userId).collection('purchases').doc(docId).set({
        'appId': appPrefix,
        'appName': FlavorConfig.current.appName,
        'flavor': currentFlavor.name,
        'userId': userId,
        'productId': productId,
        'orderId': orderId,
        'status': status ?? 'purchased',
        'quantity': quantity ?? 1,
        'timestamp': FieldValue.serverTimestamp(),
        'clientDate': now.toIso8601String(),
      }, SetOptions(merge: true));

      developer.log('Logged purchase $productId ($docId) for user $usersCollection/$userId', name: 'CloudSync');
    } catch (e, st) {
      developer.log('Failed to log purchase to Firestore', name: 'CloudSync', error: e, stackTrace: st);
    }
  }

  /// Cleans up remote data when a user deletes their account.
  Future<void> deleteUserData(String userId) async {
    try {
      await _userDoc(userId).delete();
      // Also delete legacy doc locations if any existed
      await _db.collection('users').doc('${appPrefix}_$userId').delete();
      await _db.collection('users').doc(userId).delete();
      developer.log('Deleted cloud user data for $usersCollection/$userId', name: 'CloudSync');
    } catch (e) {
      developer.log('Failed to delete cloud data for $userId', name: 'CloudSync', error: e);
    }
  }
}
