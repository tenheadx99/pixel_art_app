import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/flavor.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gallery_provider.dart';

/// Modal bottom sheet allowing users to sign in or register with Email & Password.
class EmailAuthSheet extends StatefulWidget {
  const EmailAuthSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const EmailAuthSheet(),
    );
  }

  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegister = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().clearError();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth(AuthProvider auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    auth.clearError();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    AppSettingsProvider? settings;
    GalleryProvider? gallery;
    try {
      settings = context.read<AppSettingsProvider>();
    } catch (_) {}
    try {
      gallery = context.read<GalleryProvider>();
    } catch (_) {}

    final success = _isRegister
        ? await auth.registerWithEmail(
            email: email,
            password: pass,
            settings: settings,
            gallery: gallery,
          )
        : await auth.signInWithEmail(
            email: email,
            password: pass,
            settings: settings,
            gallery: gallery,
          );

    if (success && mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isRegister
              ? 'Account created and progress backed up!'
              : 'Signed in! Your cloud progress is synced.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleForgotPassword(AuthProvider auth) async {
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty || !email.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address to reset password.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final sent = await auth.sendPasswordResetEmail(email);
    if (sent && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email. Check your inbox!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavor = FlavorConfig.current;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final auth = context.watch<AuthProvider>();

    final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF22223B);
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(76),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  _isRegister ? 'Create Cloud Account' : 'Sign In with Email',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegister
                      ? 'Save your artwork progress, diamonds, and achievements safely.'
                      : 'Access your saved diamonds and color-by-number progress.',
                  style: TextStyle(fontSize: 13, color: subtextColor),
                ),
                const SizedBox(height: 20),

                // Error display
                if (auth.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withAlpha(76)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF25253E) : const Color(0xFFF3F4F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty || !val.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password input
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!auth.isLoading) {
                      _submitAuth(auth);
                    }
                  },
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF25253E) : const Color(0xFFF3F4F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Forgot password button (only shown in Sign In mode)
                if (!_isRegister) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: auth.isLoading ? null : () => _handleForgotPassword(auth),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 12,
                          color: flavor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  const SizedBox(height: 22),
                ],

                // Action button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: flavor.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: auth.isLoading ? null : () => _submitAuth(auth),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _isRegister ? 'Create Account & Sync' : 'Sign In & Sync',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Toggle between Sign In and Register
                TextButton(
                  onPressed: () {
                    auth.clearError();
                    setState(() => _isRegister = !_isRegister);
                  },
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Create One",
                    style: TextStyle(
                      color: flavor.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
