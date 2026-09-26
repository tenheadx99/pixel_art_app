import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_constants.dart';
import '../../config/flavor.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/review_service.dart';
import '../../data/services/sound_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gallery_provider.dart';
import '../theme/app_style.dart';
import '../widgets/transitions.dart';
import '../widgets/email_auth_sheet.dart';
import 'onboarding_screen.dart';

/// Full-screen Settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavor = FlavorConfig.current;

    final settingsTitle = l10n?.settings ?? 'Settings';
    final hapticTitle = l10n?.hapticFeedback ?? 'Vibration & Haptics';
    final soundTitle = l10n?.soundEffects ?? 'Sound Effects';
    final langTitle = l10n?.language ?? 'Language';
    final rateUsTitle = l10n?.rateUs ?? 'Rate Us';
    final privacyTitle = l10n?.privacyPolicy ?? 'Privacy Policy';
    final termsTitle = l10n?.termsOfService ?? 'Terms of Service';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF7F8FD),
      appBar: AppBar(
        title: Text(
          settingsTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Section 0: Cloud Save & Account
              _buildAccountCard(context, isDark, flavor),
              const SizedBox(height: 20),

              // Section 1: Appearance & Display
              _buildSectionHeader('DISPLAY & APPEARANCE', isDark, flavor.primary),
              _buildCard(
                isDark: isDark,
                children: [
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.dark_mode_outlined, const Color(0xFF706FD3), isDark),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sleek dark theme for relaxing play', style: TextStyle(fontSize: 12)),
                    value: settings.isDarkMode,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleDarkMode();
                    },
                  ),
                  _buildDivider(isDark),
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.visibility_outlined, const Color(0xFF33D9B2), isDark),
                    title: const Text('Colorblind Patterns', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Draw distinct dot patterns on cells by color', style: TextStyle(fontSize: 12)),
                    value: settings.colorblindMode,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleColorblindMode();
                    },
                  ),
                  _buildDivider(isDark),
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.auto_awesome_outlined, const Color(0xFFFF9F1A), isDark),
                    title: const Text('Fill Particle Effects', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Play bursts and sparkles when cells are filled', style: TextStyle(fontSize: 12)),
                    value: settings.fillEffectsEnabled,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleFillEffects();
                    },
                  ),
                  if (settings.fillEffectsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Row(
                        children: [
                          const Text(
                            'Style:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'sparkles',
                                  icon: Icon(Icons.auto_awesome_rounded, size: 18),
                                  tooltip: 'Sparkles',
                                ),
                                ButtonSegment(
                                  value: 'stars',
                                  icon: Icon(Icons.star_rounded, size: 18),
                                  tooltip: 'Stars',
                                ),
                                ButtonSegment(
                                  value: 'neon',
                                  icon: Icon(Icons.blur_circular_rounded, size: 18),
                                  tooltip: 'Neon',
                                ),
                                ButtonSegment(
                                  value: 'hearts',
                                  icon: Icon(Icons.favorite_rounded, size: 18),
                                  tooltip: 'Hearts',
                                ),
                              ],
                              selected: {settings.particleStyle},
                              onSelectionChanged: (selection) {
                                if (selection.isNotEmpty) {
                                  HapticFeedback.selectionClick();
                                  settings.setParticleStyle(selection.first);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Section 2: Gameplay & Controls
              _buildSectionHeader('CONTROLS & FEEDBACK', isDark, flavor.primary),
              _buildCard(
                isDark: isDark,
                children: [
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.center_focus_strong_outlined, const Color(0xFF00F0FF), isDark),
                    title: const Text('Auto-Navigate to Next Cell', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Move camera smoothly when next number is off-screen', style: TextStyle(fontSize: 12)),
                    value: settings.autoMoveEnabled,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleAutoMove();
                    },
                  ),
                  _buildDivider(isDark),
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.vibration, const Color(0xFFFF5252), isDark),
                    title: Text(hapticTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Tactile response on taps and completions', style: TextStyle(fontSize: 12)),
                    value: settings.hapticsEnabled,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleHaptics();
                    },
                  ),
                  if (settings.hapticsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Row(
                        children: [
                          const Text(
                            'Intensity:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'soft',
                                  label: Text('Soft', style: TextStyle(fontSize: 12)),
                                ),
                                ButtonSegment(
                                  value: 'medium',
                                  label: Text('Medium', style: TextStyle(fontSize: 12)),
                                ),
                                ButtonSegment(
                                  value: 'heavy',
                                  label: Text('Heavy', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                              selected: {settings.hapticIntensity},
                              onSelectionChanged: (selection) {
                                if (selection.isNotEmpty) {
                                  settings.setHapticIntensity(selection.first);
                                  HapticFeedback.mediumImpact();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Section 3: Audio & Soundscapes
              _buildSectionHeader('AUDIO', isDark, flavor.primary),
              _buildCard(
                isDark: isDark,
                children: [
                  SwitchListTile(
                    secondary: _buildIconCircle(Icons.volume_up_outlined, const Color(0xFF2ED573), isDark),
                    title: Text(soundTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Delightful pop sounds while coloring', style: TextStyle(fontSize: 12)),
                    value: settings.soundsEnabled,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      settings.toggleSounds();
                    },
                  ),
                  _buildDivider(isDark),
                  ListTile(
                    leading: _buildIconCircle(Icons.multitrack_audio_rounded, const Color(0xFFBD93F9), isDark),
                    title: const Text('Ambient Soundscape', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_getAmbientName(settings.ambientTrack), style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showAmbientPicker(context, settings),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 4: Help, Language & Preferences
              _buildSectionHeader('GUIDE & LANGUAGE', isDark, flavor.primary),
              _buildCard(
                isDark: isDark,
                children: [
                  ListTile(
                    leading: _buildIconCircle(Icons.school_outlined, const Color(0xFFFF793F), isDark),
                    title: const Text('How to Play (Guide)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Interactive tutorial on tools, zoom & bombs', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        fadeThroughRoute(
                          const OnboardingScreen(isReplay: true),
                          name: 'onboarding_guide',
                        ),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  ListTile(
                    leading: _buildIconCircle(Icons.language_outlined, const Color(0xFF34ACE0), isDark),
                    title: Text(langTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_getLanguageName(settings.appLocale, l10n), style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showLanguagePicker(context, settings, l10n),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 5: Legal & Version
              _buildSectionHeader('ABOUT', isDark, flavor.primary),
              _buildCard(
                isDark: isDark,
                children: [
                  ListTile(
                    leading: _buildIconCircle(Icons.star_rounded, const Color(0xFFFFB300), isDark),
                    title: Text(rateUsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Rate your experience in the app', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ReviewService().requestInAppReview(
                        storage: context.read<LocalStorageService>(),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  ListTile(
                    leading: _buildIconCircle(Icons.privacy_tip_outlined, Colors.grey, isDark),
                    title: Text(privacyTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                  ),
                  _buildDivider(isDark),
                  ListTile(
                    leading: _buildIconCircle(Icons.description_outlined, Colors.grey, isDark),
                    title: Text(termsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _openUrl(AppConstants.termsUrl),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // App Version Badge
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return Text(
                    info == null
                        ? flavor.appName
                        : '${flavor.appName} v${info.version} (${info.buildNumber})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, Color brandColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: isDark ? Colors.white54 : brandColor.withAlpha(200),
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18172B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      endIndent: 16,
      color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
    );
  }

  Widget _buildIconCircle(IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(isDark ? 35 : 25),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _getAmbientName(String track) {
    switch (track) {
      case 'rain':
        return 'Soft Rain 🌧️';
      case 'ocean':
        return 'Gentle Waves 🌊';
      case 'zen':
        return 'Zen Chimes 🧘';
      case 'none':
      default:
        return 'Off';
    }
  }

  void _showAmbientPicker(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final options = [
          {'key': 'none', 'label': 'Off'},
          {'key': 'rain', 'label': 'Soft Rain 🌧️'},
          {'key': 'ocean', 'label': 'Gentle Waves 🌊'},
          {'key': 'zen', 'label': 'Zen Chimes 🧘'},
        ];

        return AlertDialog(
          title: const Text('Ambient Soundscape'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final key = opt['key'] as String;
              final label = opt['label'] as String;
              final isSelected = settings.ambientTrack == key;
              return ListTile(
                title: Text(label),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppStyle.primary : Colors.grey,
                ),
                onTap: () {
                  settings.setAmbientTrack(key);
                  context.read<SoundService>().playAmbient(key);
                  Navigator.pop(dialogContext);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageName(Locale? locale, AppLocalizations? l10n) {
    if (locale == null) return l10n?.systemDefault ?? 'System Default';
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'ja':
        return '日本語 (Japanese)';
      case 'es':
        return 'Español (Spanish)';
      case 'pt':
        return 'Português (Portuguese)';
      default:
        return locale.languageCode;
    }
  }

  void _showLanguagePicker(
    BuildContext context,
    AppSettingsProvider settings,
    AppLocalizations? l10n,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final options = [
          {'locale': null, 'label': l10n?.systemDefault ?? 'System Default'},
          {'locale': const Locale('en'), 'label': 'English'},
          {'locale': const Locale('hi'), 'label': 'हिन्दी (Hindi)'},
          {'locale': const Locale('ja'), 'label': '日本語 (Japanese)'},
          {'locale': const Locale('es'), 'label': 'Español (Spanish)'},
          {'locale': const Locale('pt'), 'label': 'Português (Portuguese)'},
        ];

        return AlertDialog(
          title: Text(l10n?.language ?? 'Language'),
          content: RadioGroup<Locale?>(
            groupValue: settings.appLocale,
            onChanged: (selected) {
              settings.setAppLocale(selected);
              Navigator.pop(dialogContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final loc = opt['locale'] as Locale?;
                final label = opt['label'] as String;
                final isSelected = settings.appLocale == loc;
                return RadioListTile<Locale?>(
                  title: Text(label),
                  value: loc,
                  selected: isSelected,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountCard(BuildContext context, bool isDark, FlavorConfig flavor) {
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context, listen: true);
    } catch (_) {
      auth = null;
    }
    if (auth == null) {
      return const SizedBox.shrink();
    }
    final authProvider = auth;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15);
    final textColor = isDark ? Colors.white : const Color(0xFF22223B);
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    if (authProvider.isAuthenticated) {
          final user = authProvider.user;
          final displayName = user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : (user?.email?.split('@').first ?? 'Player');
          final email = user?.email ?? '';

          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: flavor.primary.withAlpha(40),
                      backgroundImage: (authProvider.photoUrl != null && authProvider.photoUrl!.isNotEmpty)
                          ? NetworkImage(authProvider.photoUrl!)
                          : null,
                      child: (authProvider.photoUrl == null || authProvider.photoUrl!.isEmpty)
                          ? Text(
                              displayName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: flavor.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_done_rounded, color: Colors.green, size: 12),
                                    SizedBox(width: 3),
                                    Text(
                                      'Synced',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: subtextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      icon: authProvider.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.sync_rounded, size: 16, color: flavor.primary),
                      label: Text(
                        authProvider.isSyncing ? 'Syncing...' : 'Sync Now',
                        style: TextStyle(fontSize: 13, color: flavor.primary, fontWeight: FontWeight.w600),
                      ),
                      onPressed: authProvider.isSyncing
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final settings = context.read<AppSettingsProvider>();
                              final gallery = context.read<GalleryProvider>();
                              final res = await authProvider.syncCloudData(settings: settings, gallery: gallery);
                              if (res != null && res.success) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Cloud sync completed!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.grey),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      onPressed: () => authProvider.signOut(),
                    ),
                  ],
                ),
                Center(
                  child: TextButton(
                    onPressed: () => _showDeleteAccountDialog(context, authProvider),
                    child: const Text(
                      'Delete Account & Data',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Guest / Not signed in
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E2E), const Color(0xFF26243A)]
                  : [Colors.white, const Color(0xFFF3F2FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: flavor.primary.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_sync_rounded, color: flavor.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Save & Backup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Playing as Guest',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Back up your earned diamonds, artwork unlocks, and stats across devices safely.',
                style: TextStyle(fontSize: 12.5, color: subtextColor, height: 1.3),
              ),
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : const Color(0xFF1F1F1F),
                  foregroundColor: isDark ? Colors.black87 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: authProvider.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata_rounded, size: 26, color: Colors.blueAccent),
                label: Text(
                  authProvider.isLoading ? 'Connecting...' : 'Sign In with Google',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: authProvider.isLoading
                    ? null
                    : () {
                        final settings = context.read<AppSettingsProvider>();
                        final gallery = context.read<GalleryProvider>();
                        authProvider.signInWithGoogle(settings: settings, gallery: gallery);
                      },
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => EmailAuthSheet.show(context),
                  child: Text(
                    'Or use Email & Password',
                    style: TextStyle(
                      fontSize: 12,
                      color: flavor.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Cloud Account?'),
        content: const Text(
          'This will permanently delete your cloud account and backed up data. Local progress on this device will be preserved as a guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await auth.deleteAccount();
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted.')),
                );
              }
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
