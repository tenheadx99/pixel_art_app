import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Manages authentication using a phased approach:
/// - Silent Anonymous authentication on launch (zero-friction casual play)
/// - Optional upgrade to Google Sign-In (one-tap native account linking)
/// - Optional Email/Password authentication
/// - Account deletion compliance for Google Play Store policies
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '433057017992-k6rigublc38tehbfkdfalj8f99eiuo0g.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;
  bool get isAuthenticated => currentUser != null && !isAnonymous;
  String? get uid => currentUser?.uid;
  String? get email => currentUser?.email;
  String? get displayName => currentUser?.displayName;
  String? get photoUrl => currentUser?.photoURL;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Silently signs in anonymously if no user session exists.
  /// Runs in background without blocking gameplay or showing UI prompts.
  Future<User?> initialize() async {
    try {
      if (_auth.currentUser == null) {
        developer.log('Initializing silent anonymous authentication...', name: 'AuthService');
        return await _signInAnonymouslySafely();
      }
      return _auth.currentUser;
    } catch (e, st) {
      developer.log('Anonymous sign-in failed (continuing offline)', name: 'AuthService', error: e, stackTrace: st);
      return null;
    }
  }

  /// Links the current anonymous user with Google credentials.
  /// If the Google account is already used by an existing account, logs into that account instead.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in was cancelled',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        // Upgrade current anonymous session so local progress carries over directly
        final result = await current.linkWithCredential(credential);
        developer.log('Successfully upgraded anonymous user to Google account: ${result.user?.email}', name: 'AuthService');
        return result;
      } on FirebaseAuthException catch (e) {
        // If this Google credential belongs to a pre-existing account, sign into it
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          developer.log('Google account already exists. Signing into existing account.', name: 'AuthService');
          return await _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    } else {
      return await _auth.signInWithCredential(credential);
    }
  }

  /// Links or signs in with Email and Password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new account with Email and Password and links it to the current anonymous session.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          // Fallback to direct sign-in if account exists
          return await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        }
        rethrow;
      }
    } else {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  /// Signs out of the permanent account and immediately creates a fresh anonymous account.
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      // Drop back to anonymous guest mode safely
      await _signInAnonymouslySafely();
    } catch (e, st) {
      developer.log('Error during sign out', name: 'AuthService', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Permanently deletes the user account (required for Google Play Store compliance).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await user.delete();
      // Return to a fresh anonymous session safely
      await _signInAnonymouslySafely();
    } catch (e, st) {
      developer.log('Error deleting account', name: 'AuthService', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Safely signs in anonymously, absorbing the known Pigeon deserialization
  /// type cast bug (`List<Object?>` vs `PigeonUserDetails`) in FlutterFire on Android,
  /// while still ensuring the underlying native Firebase anonymous session is active.
  Future<User?> _signInAnonymouslySafely() async {
    try {
      final credential = await _auth.signInAnonymously();
      developer.log('Anonymous sign-in complete. UID: ${credential.user?.uid}', name: 'AuthService');
      return credential.user;
    } catch (e, st) {
      if (e is TypeError || e.toString().contains('PigeonUserDetails')) {
        developer.log(
          'Absorbed known Pigeon deserialization bug in signInAnonymously. Native currentUser is: ${_auth.currentUser?.uid}',
          name: 'AuthService',
        );
        return _auth.currentUser;
      }
      developer.log('Anonymous sign-in error', name: 'AuthService', error: e, stackTrace: st);
      return null;
    }
  }
}
