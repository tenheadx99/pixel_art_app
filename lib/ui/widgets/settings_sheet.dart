import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_constants.dart';
import '../../data/services/iap_service.dart';
import '../../providers/app_settings_provider.dart';
import '../theme/app_style.dart';
import '../../config/flavor.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  value: settings.isDarkMode,
                  onChanged: (_) => settings.toggleDarkMode(),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Colorblind patterns'),
                  subtitle: const Text('Draw dot patterns on cells by color'),
                  value: settings.colorblindMode,
                  onChanged: (_) => settings.toggleColorblindMode(),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Haptic feedback'),
                  value: settings.hapticsEnabled,
                  onChanged: (_) => settings.toggleHaptics(),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('ASMR Sound effects'),
                  value: settings.soundsEnabled,
                  onChanged: (_) => settings.toggleSounds(),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Fill effects'),
                  subtitle: const Text('Pops, sparkles & combos while coloring'),
                  value: settings.fillEffectsEnabled,
                  onChanged: (_) => settings.toggleFillEffects(),
                ),
                if (settings.soundsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.music_note_outlined,
                          size: 24,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Sound style',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'bubble_pop',
                              label: Text('Pop'),
                            ),
                            ButtonSegment(
                              value: 'light_click',
                              label: Text('Click'),
                            ),
                          ],
                          selected: {settings.soundType},
                          onSelectionChanged: (value) {
                            settings.setSoundType(value.first);
                          },
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 8),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Daily reminders'),
                  subtitle: const Text(
                    'Gentle morning & evening nudges to relax with a fresh canvas',
                  ),
                  value: settings.dailyRemindersEnabled,
                  onChanged: (value) =>
                      settings.setDailyRemindersEnabled(value),
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore purchases'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await context.read<IAPService>().restorePurchases();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Restore requested — purchases re-apply in a moment.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of service'),
                  onTap: () => _openUrl(AppConstants.termsUrl),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        info == null
                            ? FlavorConfig.current.appName
                            : '${FlavorConfig.current.appName} v${info.version} (${info.buildNumber})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyle.primary.withAlpha(150),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
