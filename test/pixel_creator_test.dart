import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/ui/screens/pixel_creator_screen.dart';

void main() {
  test('AppConstants.supportedGridSizes includes 48 and 64', () {
    expect(AppConstants.supportedGridSizes, containsAll([16, 24, 32, 48, 64]));
  });

  testWidgets('PixelCreatorScreen initializes correctly with 48x48 grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PixelCreatorScreen(
          title: 'Test 48',
          size: 48,
          paletteStyle: 'retro',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(PixelCreatorScreen));
    expect(find.text('Test 48'), findsOneWidget);
    expect(state, isNotNull);
  });

  testWidgets('PixelCreatorScreen initializes correctly with 64x64 grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PixelCreatorScreen(
          title: 'Test 64',
          size: 64,
          paletteStyle: 'retro',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(PixelCreatorScreen));
    expect(find.text('Test 64'), findsOneWidget);
    expect(state, isNotNull);
  });
}

