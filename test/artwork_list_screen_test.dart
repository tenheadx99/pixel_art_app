import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/database_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/providers/gallery_provider.dart';
import 'package:pixel_art_app/ui/screens/artwork_list_screen.dart';
import 'package:pixel_art_app/ui/widgets/ad_banner.dart';
import 'package:pixel_art_app/ui/widgets/pixel_art_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late DatabaseService db;
  late AppSettingsProvider settings;
  late GalleryProvider gallery;

  final List<PixelArt> sampleArtworks = [
    PixelArt(
      id: 'art_1',
      name: 'Anime Hero',
      category: 'Anime',
      gridWidth: 16,
      gridHeight: 16,
      grid: List.generate(16, (_) => List.filled(16, 1)),
      colorMap: {1: const Color(0xFFFF0000)},
    ),
    PixelArt(
      id: 'art_2',
      name: 'Cute Chibi',
      category: 'Chibi',
      gridWidth: 16,
      gridHeight: 16,
      grid: List.generate(16, (_) => List.filled(16, 2)),
      colorMap: {2: const Color(0xFF00FF00)},
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    db = DatabaseService();
    settings = AppSettingsProvider(storage);
    gallery = GalleryProvider(storage, db);
    await gallery.loadCatalog(sampleArtworks);
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: gallery),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('ArtworkListScreen renders list of artworks and bottom banner ad', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        ArtworkListScreen(
          title: 'Anime Shelf',
          artworks: sampleArtworks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and item count
    expect(find.text('Anime Shelf'), findsOneWidget);
    expect(find.text('2 artworks'), findsOneWidget);

    // Verify PixelArtCard is rendered for artworks
    expect(find.byType(PixelArtCard), findsNWidgets(2));
    expect(find.byWidgetPredicate((w) => w is PixelArtCard && w.art.name == 'Anime Hero'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PixelArtCard && w.art.name == 'Cute Chibi'), findsOneWidget);

    // Verify AdBanner is present at the bottom
    expect(find.byType(AdBanner), findsOneWidget);
  });

  testWidgets('ArtworkListScreen search filters artwork list', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        ArtworkListScreen(
          title: 'All Artworks',
          artworks: sampleArtworks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap search icon in AppBar
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    // Enter search query "Chibi"
    await tester.enterText(find.byType(TextField), 'Chibi');
    await tester.pumpAndSettle();

    // Should only show "Cute Chibi"
    expect(find.byWidgetPredicate((w) => w is PixelArtCard && w.art.name == 'Cute Chibi'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PixelArtCard && w.art.name == 'Anime Hero'), findsNothing);
  });
}
