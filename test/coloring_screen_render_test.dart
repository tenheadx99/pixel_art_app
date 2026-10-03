import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/ad_service.dart';
import 'package:pixel_art_app/data/services/daily_pixel_service.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/iap_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_catalog_service.dart';
import 'package:pixel_art_app/data/services/screenshot_service.dart';
import 'package:pixel_art_app/data/services/sound_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/coloring_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/ui/screens/coloring_screen.dart';
import 'package:pixel_art_app/ui/widgets/pixel_grid.dart';

void main() {
  testWidgets('ColoringScreen loads and renders PixelGrid for devotional art', (tester) async {
    print('Starting test...');
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final db = DatabaseService();
    final sound = SoundService();
    final remoteCatalog = RemoteCatalogService(storage);
    final dailyPixel = DailyPixelService(storage);

    final raw = await File('assets/pixel_art_devotional/diya.json').readAsString();
    final art = PixelArt.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final coloringProvider = ColoringProvider(storage);
    final settingsProvider = AppSettingsProvider(storage)..loadSettings();
    final galleryProvider = GalleryProvider(storage, db, remoteCatalog, dailyPixel);

    print('Pumping widget...');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalStorageService>.value(value: storage),
          Provider<DatabaseService>.value(value: db),
          Provider<SoundService>.value(value: sound),
          Provider<AdService>.value(value: AdService()),
          ChangeNotifierProvider<ColoringProvider>.value(value: coloringProvider),
          ChangeNotifierProvider<AppSettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<GalleryProvider>.value(value: galleryProvider),
        ],
        child: MaterialApp(
          home: ColoringScreen(art: art),
        ),
      ),
    );
    print('Pumped initial widget!');

    // Let post frame callback run and complete
    print('Pumping next frame...');
    await tester.pump();
    print('Pumped 1 frame!');
    await tester.pump(const Duration(milliseconds: 500));
    print('Pumped 500ms!');

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PixelGrid), findsOneWidget);
    print('Success!');
  });
}
