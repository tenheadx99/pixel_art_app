import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'analytics_service.dart';

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
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  bool get isAuthenticated => currentUser != null && !isAnonymous;
  String? get uid => currentUser?.uid;
  String? get email => currentUser?.email;
  String? get displayName => currentUser?.displayName;
  String? get photoUrl => currentUser?.photoURL;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the current user session (e.g. returning Google or Email sign-in).
  /// Guest users play offline without silent anonymous authentication.
  Future<User?> initialize() async {
    return _auth.currentUser;
  }

  /// Links the current anonymous user with Google credentials.
  /// If the Google account is already used by an existing account, logs into that account instead.
  Future<User?> signInWithGoogle() async {
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
        final user = await _wrapAuthCall(() => current.linkWithCredential(credential));
        developer.log('Successfully upgraded anonymous user to Google account: ${user?.email}', name: 'AuthService');
        AnalyticsService().logAccountLinked(provider: 'google');
        return user;
      } on FirebaseAuthException catch (e) {
        // If this Google credential belongs to a pre-existing account, sign into it
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          developer.log('Google account already exists. Signing into existing account.', name: 'AuthService');
          return await _wrapAuthCall(() => _auth.signInWithCredential(credential));
        }
        rethrow;
      }
    } else {
      return await _wrapAuthCall(() => _auth.signInWithCredential(credential));
    }
  }

  /// Links or signs in with Email and Password.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _wrapAuthCall(() => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ));
  }

  /// Registers a new account with Email and Password and links it to the current anonymous session.
  Future<User?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      try {
        final user = await _wrapAuthCall(() => current.linkWithCredential(credential));
        AnalyticsService().logAccountLinked(provider: 'email');
        return user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          // If the account already exists, attempt direct sign-in with the provided password.
          // If sign-in fails (e.g. different password entered), rethrow the original error
          // so the user receives a clear "Account already exists" message.
          try {
            return await signInWithEmail(
              email: email.trim(),
              password: password,
            );
          } catch (_) {
            rethrow;
          }
        }
        rethrow;
      }
    } else {
      return await _wrapAuthCall(() => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ));
    }
  }

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Executes an authentication operation and returns the resulting [User].
  /// Absorbs the known FlutterFire on Android Pigeon deserialization bug
  /// (`List<Object?>` vs `PigeonUserDetails`) while verifying that the native
  /// Firebase authentication completed successfully.
  Future<User?> _wrapAuthCall(Future<UserCredential> Function() call) async {
    try {
      final cred = await call();
      return cred.user ?? _auth.currentUser;
    } catch (e, st) {
      if (e is TypeError || e.toString().contains('PigeonUserDetails')) {
        developer.log(
          'Absorbed known Pigeon deserialization bug in auth call. Native user is: ${_auth.currentUser?.email ?? _auth.currentUser?.uid}',
          name: 'AuthService',
        );
        return _auth.currentUser;
      }
      developer.log('Auth call error', name: 'AuthService', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Signs out of the permanent account.
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
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
    } catch (e, st) {
      developer.log('Error deleting account', name: 'AuthService', error: e, stackTrace: st);
      rethrow;
    }
  }
}
