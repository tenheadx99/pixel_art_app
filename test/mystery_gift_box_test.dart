import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/data/models/home_engagement_config.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mystery Gift Box hides with animation when claimed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final settings = AppSettingsProvider(storage)..loadSettings();

    const engagement = HomeEngagementConfig(
      mysteryGiftBoxEnabled: true,
      mysteryGiftDiamonds: 25,
    );

    bool isClaiming = false;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final claimKey = 'mystery_gift_claimed_$todayStr';

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final isClaimed = storage.getBool(claimKey, defaultValue: false);
              final shouldShow = !isClaimed && !isClaiming;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                reverseDuration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                  );
                },
                child: shouldShow
                    ? InkWell(
                        key: const ValueKey('mystery_gift_box_card'),
                        onTap: () {
                          storage.setBool(claimKey, true);
                          settings.addDiamonds(engagement.mysteryGiftDiamonds);
                          setState(() {
                            isClaiming = true;
                          });
                        },
                        child: const Text('Mystery Diamond Gift'),
                      )
                    : const SizedBox.shrink(key: ValueKey('mystery_gift_box_hidden')),
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Box is visible
    expect(find.byKey(const ValueKey('mystery_gift_box_card')), findsOneWidget);
    expect(find.text('Mystery Diamond Gift'), findsOneWidget);

    final initialDiamonds = settings.diamondsAvailable;

    // Tap to claim
    await tester.tap(find.text('Mystery Diamond Gift'));
    // Advance partially to check animation is in progress
    await tester.pump(const Duration(milliseconds: 200));

    // Diamonds were added
    expect(settings.diamondsAvailable, equals(initialDiamonds + 25));
    expect(storage.getBool(claimKey), isTrue);

    // Let animation finish
    await tester.pumpAndSettle();

    // Box is now hidden
    expect(find.byKey(const ValueKey('mystery_gift_box_card')), findsNothing);
    expect(find.byKey(const ValueKey('mystery_gift_box_hidden')), findsOneWidget);
  });
}
