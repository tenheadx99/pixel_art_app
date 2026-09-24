import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/data/models/user_artwork.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/l10n/app_localizations.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/ui/screens/gallery_screen.dart';

class _MockDatabaseService extends DatabaseService {
  List<Map<String, dynamic>> saved = [];
  final List<String> deletedIds = [];
  final List<String> deletedPixelArtIds = [];

  @override
  Future<List<Map<String, dynamic>>> getSavedArtworks() async {
    return List.from(saved);
  }

  @override
  Future<void> deleteArtwork(String id) async {
    deletedIds.add(id);
    saved.removeWhere((m) => m['id'] == id);
  }

  @override
  Future<void> deleteArtworksByPixelArtId(String pixelArtId) async {
    deletedPixelArtIds.add(pixelArtId);
    saved.removeWhere((m) => m['pixel_art_id'] == pixelArtId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AppSettingsProvider settings;
  late _MockDatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    settings = AppSettingsProvider(storage);
    db = _MockDatabaseService();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GalleryScreen(),
      ),
    );
  }

  testWidgets('GalleryScreen shows only unique artworks when duplicates exist in database',
      (tester) async {
    // Two entries for 'art_cat' (one older partial 50%, one newer complete 100%)
    // and one entry for 'art_dog'
    db.saved = [
      UserArtwork(
        id: 'dup_cat_2',
        pixelArtId: 'art_cat',
        name: 'Cat',
        filePath: '/mock/cat_new.png',
        dateCreated: DateTime(2026, 9, 24, 12, 0),
        completionPercent: 100,
      ).toJson(),
      UserArtwork(
        id: 'dup_cat_1',
        pixelArtId: 'art_cat',
        name: 'Cat',
        filePath: '/mock/cat_old.png',
        dateCreated: DateTime(2026, 9, 24, 10, 0),
        completionPercent: 50,
      ).toJson(),
      UserArtwork(
        id: 'dog_1',
        pixelArtId: 'art_dog',
        name: 'Dog',
        filePath: '/mock/dog.png',
        dateCreated: DateTime(2026, 9, 24, 11, 0),
        completionPercent: 100,
      ).toJson(),
    ];

    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verify only 2 unique artwork cards are shown, not 3
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);

    // Verify duplicate entry was pruned from database
    expect(db.deletedIds, contains('dup_cat_1'));
    expect(db.deletedIds, isNot(contains('dup_cat_2')));
  });

  test('GalleryProvider deduplicates preMade catalog', () async {
    final provider = GalleryProvider(storage, db);
    final art1 = PixelArt(
      id: 'same_id',
      name: 'Item 1',
      gridWidth: 1,
      gridHeight: 1,
      grid: const [[1]],
      colorMap: const {1: Color(0xFF000000)},
    );
    final art2 = PixelArt(
      id: 'same_id',
      name: 'Item 2 Duplicate',
      gridWidth: 1,
      gridHeight: 1,
      grid: const [[1]],
      colorMap: const {1: Color(0xFF000000)},
    );
    final art3 = PixelArt(
      id: 'unique_id',
      name: 'Item 3',
      gridWidth: 1,
      gridHeight: 1,
      grid: const [[1]],
      colorMap: const {1: Color(0xFF000000)},
    );

    await provider.loadCatalog([art1, art2, art3]);
    expect(provider.catalog.length, 2);
    expect(provider.catalog.map((a) => a.id).toList(), ['same_id', 'unique_id']);
  });
}
