import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/ui/widgets/combo_meter_badge.dart';
import 'package:pixel_art_app/ui/widgets/zen_overdrive_vignette.dart';

void main() {
  group('Combo & Zen Overdrive Configuration', () {
    test('AppConstants contains Zen Overdrive thresholds', () {
      expect(AppConstants.zenOverdriveComboThreshold, 30);
      expect(AppConstants.zenOverdriveBonusDiamonds, 5);
      expect(AppConstants.comboThresholds.contains(30), isTrue);
    });
  });

  group('ComboMeterBadge Widget', () {
    testWidgets('Hidden when combo is below 3', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 2),
          ),
        ),
      );
      await tester.pump();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0.0);
    });

    testWidgets('Displays COMBO tier when combo is 3', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 3),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x3'), findsOneWidget);
      expect(find.text('COMBO'), findsOneWidget);
    });

    testWidgets('Displays HOT tier when combo is 5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 5),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x5'), findsOneWidget);
      expect(find.text('HOT'), findsOneWidget);
    });

    testWidgets('Displays SUPER tier when combo is 10', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 10),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x10'), findsOneWidget);
      expect(find.text('SUPER'), findsOneWidget);
    });

    testWidgets('Displays ULTRA tier when combo is 20', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 20),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x20'), findsOneWidget);
      expect(find.text('ULTRA'), findsOneWidget);
    });

    testWidgets('Displays OVERDRIVE tier when combo reaches 30', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComboMeterBadge(combo: 30),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('x30'), findsOneWidget);
      expect(find.text('OVERDRIVE'), findsOneWidget);
    });
  });

  group('ZenOverdriveVignette Widget', () {
    testWidgets('Toggles active state without errors', (tester) async {
      bool active = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ZenOverdriveVignette(
                  active: active,
                  child: const Center(child: Text('Canvas Content')),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => active = true),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Canvas Content'), findsOneWidget);
      final initialOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(initialOpacity.opacity, 0.0);

      // Trigger activation
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final activeOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(activeOpacity.opacity, 1.0);
    });
  });
}

