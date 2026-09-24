import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/ui/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
  });

  Widget createTestWidget({bool isReplay = false, VoidCallback? onFinished}) {
    return Provider<LocalStorageService>.value(
      value: storage,
      child: MaterialApp(
        home: OnboardingScreen(
          isReplay: isReplay,
          onFinished: onFinished ?? () {},
        ),
      ),
    );
  }

  Future<void> advanceFrames(WidgetTester tester, [int millis = 500]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: millis));
  }

  testWidgets('Onboarding renders first slide with basics', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await advanceFrames(tester);

    expect(find.text('Tap & Drag to Color'), findsOneWidget);
    expect(find.text('STEP 1 · THE BASICS'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Navigating through all 4 slides to completion sets has_seen_onboarding',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await advanceFrames(tester);

    expect(storage.getBool('has_seen_onboarding'), isFalse);

    // Slide 1 -> Slide 2
    await tester.tap(find.text('Next'));
    await advanceFrames(tester, 700);
    expect(find.text('Pinch to Zoom & Pan'), findsOneWidget);
    expect(find.text('STEP 2 · PRECISION'), findsOneWidget);

    // Slide 2 -> Slide 3
    await tester.tap(find.text('Next'));
    await advanceFrames(tester, 700);
    expect(find.text('Color Bomb & Boosters'), findsOneWidget);
    expect(find.text('STEP 3 · POWER-UPS'), findsOneWidget);

    // Slide 3 -> Slide 4
    await tester.tap(find.text('Next'));
    await advanceFrames(tester, 700);
    expect(find.text('Time-Lapse & Daily Art'), findsOneWidget);
    expect(find.text('STEP 4 · MASTERPIECES'), findsOneWidget);
    expect(find.text('Start Coloring!'), findsOneWidget);

    // Complete onboarding
    await tester.tap(find.byKey(const ValueKey('main_action_btn')));
    await advanceFrames(tester, 700);

    expect(storage.getBool('has_seen_onboarding'), isTrue);
  });

  testWidgets('Tapping Skip completes onboarding immediately', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await advanceFrames(tester);

    expect(storage.getBool('has_seen_onboarding'), isFalse);

    await tester.tap(find.text('Skip'));
    await advanceFrames(tester);

    expect(storage.getBool('has_seen_onboarding'), isTrue);
  });

  testWidgets('Back button navigates to previous slide', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await advanceFrames(tester);

    // Go to Slide 2
    await tester.tap(find.text('Next'));
    await advanceFrames(tester);
    expect(find.text('Pinch to Zoom & Pan'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await advanceFrames(tester);
    expect(find.text('Tap & Drag to Color'), findsOneWidget);
  });
}
