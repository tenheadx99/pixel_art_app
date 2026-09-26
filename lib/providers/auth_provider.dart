import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';
import '../data/services/cloud_sync_service.dart';
import '../data/services/local_storage_service.dart';
import 'app_settings_provider.dart';
import 'gallery_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  final LocalStorageService _storage;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;
  CloudSyncResult? _lastSyncResult;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider(this._storage) {
    _authSubscription = _authService.authStateChanges.listen((user) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  User? get user => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isAnonymous => _authService.isAnonymous;
  String? get displayName => _authService.displayName;
  String? get email => _authService.email;
  String? get photoUrl => _authService.photoUrl;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  CloudSyncResult? get lastSyncResult => _lastSyncResult;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Signs in or links with Google, then automatically triggers cloud sync.
  Future<bool> signInWithGoogle({
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();

      if (credential.user != null) {
        await syncCloudData(settings: settings, gallery: gallery);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _mapAuthError(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e, st) {
      _isLoading = false;
      final errStr = e.toString();
      developer.log('Google Sign-in error', name: 'Auth', error: e, stackTrace: st);
      if (errStr.contains('sign_in_canceled') || errStr.contains('ERROR_ABORTED_BY_USER')) {
        _errorMessage = null;
      } else if (errStr.contains('ApiException: 10') || errStr.contains('DEVELOPER_ERROR')) {
        _errorMessage = 'Configuration error (ApiException 10): Ensure debug SHA-1 is added in Firebase Console and google-services.json is updated.';
      } else {
        _errorMessage = 'Google sign-in error: $errStr';
      }
      notifyListeners();
      return false;
    }
  }

  /// Signs in with email and password.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithEmail(email: email, password: password);
      _isLoading = false;
      notifyListeners();

      if (credential.user != null) {
        await syncCloudData(settings: settings, gallery: gallery);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _mapAuthError(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An error occurred during sign in.';
      notifyListeners();
      return false;
    }
  }

  /// Registers a new account with email and password.
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.registerWithEmail(email: email, password: password);
      _isLoading = false;
      notifyListeners();

      if (credential.user != null) {
        await syncCloudData(settings: settings, gallery: gallery);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _mapAuthError(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An error occurred during registration.';
      notifyListeners();
      return false;
    }
  }

  /// Manually synchronizes local diamonds, XP, and artwork unlocks with Firestore.
  Future<CloudSyncResult?> syncCloudData({
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    final uid = _authService.uid;
    if (uid == null) return null;

    _isSyncing = true;
    notifyListeners();

    final result = await _cloudSyncService.syncUserData(
      userId: uid,
      storage: _storage,
      settingsProvider: settings,
      galleryProvider: gallery,
    );

    _isSyncing = false;
    if (result.success) {
      _lastSyncedAt = result.syncedAt;
      _lastSyncResult = result;
    } else {
      _errorMessage = 'Cloud sync failed: ${result.error}';
    }
    notifyListeners();
    return result;
  }

  /// Signs out of permanent account and drops back to anonymous play.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signOut();
      _lastSyncedAt = null;
      _lastSyncResult = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Sign out error: $e';
      notifyListeners();
    }
  }

  /// Deletes account permanently (meeting Google Play Policy).
  Future<bool> deleteAccount() async {
    final uid = _authService.uid;
    _isLoading = true;
    notifyListeners();
    try {
      if (uid != null) {
        await _cloudSyncService.deleteUserData(uid);
      }
      await _authService.deleteAccount();
      _lastSyncedAt = null;
      _lastSyncResult = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        _errorMessage = 'For security, please sign out and sign in again before deleting your account.';
      } else if (e is TypeError || e.toString().contains('PigeonUserDetails')) {
        // Account was successfully deleted on Firebase; post-deletion anonymous token return hit Pigeon bug
        _lastSyncedAt = null;
        _lastSyncResult = null;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to delete account: $e';
      }
      notifyListeners();
      return false;
    }
  }

  String _mapAuthError(String code, String? defaultMsg) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network connection issue. Please check your internet.';
      default:
        return defaultMsg ?? 'Authentication error occurred.';
    }
  }
}
