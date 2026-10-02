import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_art_app/data/services/app_config_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/ui/widgets/in_app_update_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AppConfigService configService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();

    configService = AppConfigService();
    configService.attachStorage(storage);
    configService.resetStateForTesting();

    // Mock url_launcher channel so launchStore() doesn't fail
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: InAppUpdateCard(),
            ),
          ],
        ),
      ),
    );
  }

  group('InAppUpdateCard on Artwork Screen', () {
    testWidgets('UI component does not appear when app is already updated', (tester) async {
      configService.setCurrentAppVersionForTesting('2.0.0');
      configService.setTargetVersionForTesting('2.0.0');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Update Now'), findsNothing);
      expect(find.text('Exciting Update Available!'), findsNothing);
    });

    testWidgets('UI component appears when a newer update is available', (tester) async {
      configService.setCurrentAppVersionForTesting('1.0.0');
      configService.setTargetVersionForTesting('2.0.0');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
    });

    testWidgets(
      'it should hide on click of update button',
      (tester) async {
        configService.setCurrentAppVersionForTesting('1.0.0');
        configService.setTargetVersionForTesting('2.0.0');

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Update Now'), findsOneWidget);

        // User clicks on "Update Now" button
        final updateBtn = find.byKey(const Key('in_app_update_card_update_btn'));
        expect(updateBtn, findsOneWidget);
        await tester.tap(updateBtn);
        await tester.pumpAndSettle();

        // Verify update app UI component hides on click of update button
        expect(configService.isDismissedThisSession, isTrue);
        expect(configService.shouldShowUpdateCard, isFalse);
        expect(find.text('Update Now'), findsNothing);
        expect(find.text('Exciting Update Available!'), findsNothing);
      },
    );

    testWidgets(
      'it should hide if app version gets updated',
      (tester) async {
        configService.setTargetVersionForTesting('2.0.0');

        // Initially on older version
        configService.setCurrentAppVersionForTesting('1.0.0');
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Update Now'), findsOneWidget);

        // App version gets updated to 2.0.0
        configService.setCurrentAppVersionForTesting('2.0.0');
        await tester.pumpAndSettle();

        // Update app UI component hides because version is updated
        expect(configService.isUpdateAvailable, isFalse);
        expect(configService.shouldShowUpdateCard, isFalse);
        expect(find.text('Update Now'), findsNothing);
        expect(find.text('Exciting Update Available!'), findsNothing);
      },
    );

    testWidgets(
      'if app version is not updated it should be shown',
      (tester) async {
        configService.setTargetVersionForTesting('2.0.0');
        configService.setCurrentAppVersionForTesting('1.0.0');

        // User clicked update in a previous session
        configService.dismissForSession();
        expect(configService.shouldShowUpdateCard, isFalse);

        // In a new session where session resets, app version is still not updated (1.0.0 < 2.0.0)
        configService.resetStateForTesting();

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // It should be shown because app version is not updated
        expect(configService.isUpdateAvailable, isTrue);
        expect(configService.shouldShowUpdateCard, isTrue);
        expect(find.text('Update Now'), findsOneWidget);
        expect(find.text('Exciting Update Available!'), findsOneWidget);
      },
    );
  });
}
