import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/sound_service.dart';
import 'package:pixel_art_app/l10n/app_localizations.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/ui/screens/profile_screen.dart';
import 'package:pixel_art_app/ui/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late DatabaseService database;
  late AppSettingsProvider settings;
  late GalleryProvider gallery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    database = DatabaseService();
    settings = AppSettingsProvider(storage);
    gallery = GalleryProvider(storage, database);
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
        ChangeNotifierProvider<GalleryProvider>.value(value: gallery),
        Provider<SoundService>.value(value: SoundService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('ProfileScreen renders Draw Canvas, My Gallery, and VIP Pass card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const ProfileScreen()));
    await tester.pumpAndSettle();

    // Verify Draw Canvas card exists
    expect(find.text('Draw Canvas'), findsOneWidget);
    expect(find.text('Create or convert'), findsOneWidget);

    // Verify My Gallery card exists
    expect(find.text('My Gallery'), findsOneWidget);

    // Verify Upgrade to VIP Pass card exists on Profile screen
    expect(find.text('Upgrade to VIP Pass'), findsOneWidget);

    // Tap Draw Canvas and verify bottom sheet options
    await tester.tap(find.text('Draw Canvas'));
    await tester.pumpAndSettle();

    expect(find.text('Draw Canvas Studio'), findsOneWidget);
    expect(find.text('Create Your Own'), findsOneWidget);
    expect(find.text('Take with Camera'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('SettingsScreen does NOT render Upgrade to VIP Pass for free users', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(const SettingsScreen()));
    await tester.pumpAndSettle();

    // Upgrade to VIP Pass should not appear on settings screen
    expect(find.text('Upgrade to VIP Pass'), findsNothing);
  });
}
