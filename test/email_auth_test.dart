import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pixel_art_app/providers/auth_provider.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/ui/widgets/email_auth_sheet.dart';
import 'package:pixel_art_app/data/services/cloud_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final bool isAnonymous;

  FakeUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isAnonymous = false,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final bool _isLoading = false;
  final bool _isSyncing = false;
  String? _errorMessage;
  User? _user;
  bool _isAuthenticated = false;

  String? lastEmailPassed;
  String? lastPasswordPassed;
  String? lastResetEmailPassed;
  bool signInShouldSucceed = true;
  bool registerShouldSucceed = true;
  bool resetShouldSucceed = true;

  @override
  bool get isLoading => _isLoading;
  @override
  bool get isSyncing => _isSyncing;
  @override
  String? get errorMessage => _errorMessage;
  @override
  User? get user => _user;
  @override
  bool get isAuthenticated => _isAuthenticated;
  @override
  bool get isAnonymous => _user?.isAnonymous ?? true;
  @override
  String? get displayName => _user?.displayName;
  @override
  String? get email => _user?.email;
  @override
  String? get photoUrl => _user?.photoURL;
  @override
  DateTime? get lastSyncedAt => null;
  @override
  CloudSyncResult? get lastSyncResult => null;

  void setUser(User? user, {bool authenticated = true}) {
    _user = user;
    _isAuthenticated = authenticated;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    lastEmailPassed = email;
    lastPasswordPassed = password;
    if (signInShouldSucceed) {
      _user = FakeUser(uid: 'uid-123', email: email);
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Incorrect email or password.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    AppSettingsProvider? settings,
    GalleryProvider? gallery,
  }) async {
    lastEmailPassed = email;
    lastPasswordPassed = password;
    if (registerShouldSucceed) {
      _user = FakeUser(uid: 'uid-456', email: email);
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'An account already exists with this email.';
      notifyListeners();
      return false;
    }
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    lastResetEmailPassed = email;
    if (resetShouldSucceed) {
      return true;
    } else {
      _errorMessage = 'No account found with this email.';
      notifyListeners();
      return false;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthProvider fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthProvider();
  });

  Widget buildTestApp({Widget? child}) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: fakeAuth,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => child ?? ElevatedButton(
              onPressed: () => EmailAuthSheet.show(context),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('EmailAuthSheet renders correctly in Sign In mode by default', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In with Email'), findsOneWidget);
    expect(find.text('Access your saved diamonds and color-by-number progress.'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In & Sync'), findsOneWidget);
    expect(find.text("Don't have an account? Create One"), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('Toggling between Sign In and Register switches UI labels and controls', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Toggle to Create One
    await tester.tap(find.text("Don't have an account? Create One"));
    await tester.pumpAndSettle();

    expect(find.text('Create Cloud Account'), findsOneWidget);
    expect(find.text('Save your artwork progress, diamonds, and achievements safely.'), findsOneWidget);
    expect(find.text('Create Account & Sync'), findsOneWidget);
    expect(find.text('Already have an account? Sign In'), findsOneWidget);
    // Forgot password should not appear in register mode
    expect(find.text('Forgot Password?'), findsNothing);

    // Toggle back to Sign In
    await tester.tap(find.text('Already have an account? Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In with Email'), findsOneWidget);
    expect(find.text('Sign In & Sync'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('Form validation enforces valid email and minimum password length', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Tap submit with empty fields
    await tester.tap(find.text('Sign In & Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    // Enter email without @
    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'invalidemail');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');
    await tester.tap(find.text('Sign In & Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Password visibility toggle toggles obscureText property', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify initial obscureText state on password field
    final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
    final textFieldFinder = find.descendant(of: passwordFieldFinder, matching: find.byType(TextField));
    TextField textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.obscureText, isTrue);

    // Tap visibility toggle icon
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.obscureText, isFalse);

    // Tap again to obscure
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.obscureText, isTrue);
  });

  testWidgets('Sign in succeeds and shows confirmation SnackBar', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'player@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');

    await tester.tap(find.text('Sign In & Sync'));
    await tester.pumpAndSettle();

    // Verify inputs passed to auth provider
    expect(fakeAuth.lastEmailPassed, 'player@example.com');
    expect(fakeAuth.lastPasswordPassed, 'secret123');

    // Bottom sheet is dismissed and success SnackBar is visible
    expect(find.byType(EmailAuthSheet), findsNothing);
    expect(find.text('Signed in! Your cloud progress is synced.'), findsOneWidget);
  });

  testWidgets('Registration succeeds and shows confirmation SnackBar', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Switch to register
    await tester.tap(find.text("Don't have an account? Create One"));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'newplayer@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'newpassword');

    await tester.tap(find.text('Create Account & Sync'));
    await tester.pumpAndSettle();

    expect(fakeAuth.lastEmailPassed, 'newplayer@example.com');
    expect(fakeAuth.lastPasswordPassed, 'newpassword');

    expect(find.byType(EmailAuthSheet), findsNothing);
    expect(find.text('Account created and progress backed up!'), findsOneWidget);
  });

  testWidgets('Sign in failure displays error message banner', (tester) async {
    fakeAuth.signInShouldSucceed = false;

    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'wrong@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');

    await tester.tap(find.text('Sign In & Sync'));
    await tester.pumpAndSettle();

    // Sheet remains open and error is shown
    expect(find.byType(EmailAuthSheet), findsOneWidget);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('Forgot password prompts when email is empty or invalid', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Tap forgot password with empty email
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email address to reset password.'), findsOneWidget);
  });

  testWidgets('Forgot password sends reset link and shows confirmation', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'reset@example.com');
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(fakeAuth.lastResetEmailPassed, 'reset@example.com');
    expect(find.text('Password reset link sent to reset@example.com. Check your inbox!'), findsOneWidget);
  });
}
