import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/ui/screens/more_apps_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MoreAppsScreen displays Top 3 Hero Cards and remaining listing apps', (tester) async {
    // Set a realistic mobile device screen size
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalStorageService>.value(value: storage),
        ],
        child: const MaterialApp(
          home: MoreAppsScreen(),
        ),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('More Games & Apps'), findsOneWidget);

    // Verify Section Headers
    expect(find.text('🔥 TOP FEATURED GAMES'), findsOneWidget);

    // Verify Top 3 Hero ranks
    expect(find.text('👑 #1 TOP FEATURED'), findsOneWidget);
    expect(find.text('🔥 #2 POPULAR HIT'), findsOneWidget);
    expect(find.text('✨ #3 MUST PLAY'), findsOneWidget);

    // Verify Install Action CTA in hero cards
    expect(find.text('GET ON GOOGLE PLAY'), findsAtLeastNWidgets(3));
  });
}
