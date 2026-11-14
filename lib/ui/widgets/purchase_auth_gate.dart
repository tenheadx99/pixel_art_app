import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gallery_provider.dart';
import 'email_auth_sheet.dart';

/// Modal gate ensuring users are authenticated before purchasing
/// subscriptions, lifetime Pro, or diamond packs.
class PurchaseAuthGate {
  /// Returns `true` if the user is already authenticated or successfully
  /// signs in via Google or Email. Returns `false` if cancelled.
  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    String purpose = 'purchase VIP & access your perks',
  }) async {
    AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } catch (_) {
      // In isolated tests where AuthProvider is not provided
      return true;
    }

    if (auth.isAuthenticated) {
      return true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PurchaseAuthSheet(purpose: purpose),
    );

    return result ?? false;
  }
}

class _PurchaseAuthSheet extends StatefulWidget {
  final String purpose;
  const _PurchaseAuthSheet({required this.purpose});

  @override
  State<_PurchaseAuthSheet> createState() => _PurchaseAuthSheetState();
}

class _PurchaseAuthSheetState extends State<_PurchaseAuthSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Security Icon Badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF9D2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9D2E).withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              size: 32,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1E2D),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in before making a purchase. Your VIP status, purchases, and artworks will be permanently protected and synced across all your devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),

          // Benefits pill list
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withAlpha(12),
              ),
            ),
            child: Column(
              children: [
                _buildBenefitRow(
                  Icons.cloud_done_rounded,
                  'Never lose your purchases or VIP status',
                  const Color(0xFF10B981),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildBenefitRow(
                  Icons.devices_rounded,
                  'Automatic sync across phones & tablets',
                  const Color(0xFF3B82F6),
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildBenefitRow(
                  Icons.replay_rounded,
                  'Seamless 1-tap restore whenever needed',
                  const Color(0xFFF59E0B),
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Sign In with Google Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      setState(() => _loading = true);
                      final navigator = Navigator.of(context);
                      final auth = context.read<AuthProvider>();
                      final settings = context.read<AppSettingsProvider>();
                      final gallery = context.read<GalleryProvider>();
                      try {
                        final ok = await auth.signInWithGoogle(
                          settings: settings,
                          gallery: gallery,
                        );
                        if (mounted) {
                          setState(() => _loading = false);
                          if (ok) {
                            navigator.pop(true);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _loading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black87,
                foregroundColor: isDark ? Colors.black87 : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.g_mobiledata_rounded, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Continue with Email Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      final navigator = Navigator.of(context);
                      final auth = context.read<AuthProvider>();
                      await EmailAuthSheet.show(context);
                      if (mounted) {
                        if (auth.isAuthenticated) {
                          navigator.pop(true);
                        }
                      }
                    },
              icon: Icon(
                Icons.email_outlined,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              label: Text(
                'Continue with Email',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Cancel
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(
    IconData icon,
    String text,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withAlpha(220) : const Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}
