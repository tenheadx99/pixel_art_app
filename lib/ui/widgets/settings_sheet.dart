import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_constants.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    l10n.settings,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  title: Text(l10n.hapticFeedback),
                  value: settings.hapticsEnabled,
                  onChanged: (_) => settings.toggleHaptics(),
                ),
                if (settings.hapticsEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        const Text(
                          'Intensity:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
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
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: Text(l10n.soundEffects),
                  value: settings.soundsEnabled,
                  onChanged: (_) => settings.toggleSounds(),
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.language),
                  subtitle: Text(_getLanguageName(settings.appLocale, l10n)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguagePicker(context, settings, l10n),
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.privacyPolicy),
                  onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.termsOfService),
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

  String _getLanguageName(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.systemDefault;
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
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final options = [
          {'locale': null, 'label': l10n.systemDefault},
          {'locale': const Locale('en'), 'label': 'English'},
          {'locale': const Locale('hi'), 'label': 'हिन्दी (Hindi)'},
          {'locale': const Locale('ja'), 'label': '日本語 (Japanese)'},
          {'locale': const Locale('es'), 'label': 'Español (Spanish)'},
          {'locale': const Locale('pt'), 'label': 'Português (Portuguese)'},
        ];

        return AlertDialog(
          title: Text(l10n.language),
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
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }
}
