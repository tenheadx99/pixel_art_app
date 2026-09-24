import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/sound_service.dart';
import 'package:pixel_art_app/l10n/app_localizations.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/ui/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AppSettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    settings = AppSettingsProvider(storage);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
        Provider<SoundService>.value(value: SoundService()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders all sections and handles interactions',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify top section
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('DISPLAY & APPEARANCE'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Colorblind Patterns'), findsOneWidget);

    // Toggle dark mode while at top
    expect(settings.isDarkMode, isFalse);
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();
    expect(settings.isDarkMode, isTrue);

    // Toggle colorblind mode
    expect(settings.colorblindMode, isFalse);
    await tester.tap(find.text('Colorblind Patterns'));
    await tester.pumpAndSettle();
    expect(settings.colorblindMode, isTrue);

    // Now scroll down to verify later sections
    await tester.scrollUntilVisible(find.text('How to Play (Guide)'), 200);
    expect(find.text('How to Play (Guide)'), findsOneWidget);
  });
}
