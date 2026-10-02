import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pixel_art_app/config/app_constants.dart';
import 'package:pixel_art_app/data/services/iap_service.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/sound_service.dart';
import 'package:pixel_art_app/l10n/app_localizations.dart';
import 'package:pixel_art_app/providers/app_settings_provider.dart';
import 'package:pixel_art_app/ui/screens/paywall_screen.dart';

class FakeIAPService implements IAPService {
  @override
  bool get isStoreAvailable => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<String?> getPrice(String productId) async => '\$4.99';

  @override
  Future<List<ProductDetails>> getProductDetails(Set<String> productIds) async => [];

  @override
  Future<bool> buyProduct(ProductDetails productDetails, {bool consumable = true}) async => false;

  @override
  Future<bool> buyPro() async => false;

  @override
  Future<bool> buySubscription(String productId) async => false;

  @override
  Future<bool> buyConsumable(String productId) async => false;

  @override
  Future<bool> buyDiamondPack(String productId) async => false;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late AppSettingsProvider settings;
  late FakeIAPService fakeIap;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.init();
    settings = AppSettingsProvider(storage);
    fakeIap = FakeIAPService();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(value: storage),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: settings),
        Provider<SoundService>.value(value: SoundService()),
        Provider<IAPService>.value(value: fakeIap),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PaywallScreen(source: 'test'),
      ),
    );
  }

  testWidgets('Cancelable Store Configuration dialog appears on failed subscription purchase and can be cancelled', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify paywall rendered
    expect(find.byType(PaywallScreen), findsOneWidget);

    // Tap the primary subscribe button
    final ctaButton = find.byType(ElevatedButton).first;
    await tester.ensureVisible(ctaButton);
    await tester.tap(ctaButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The cancelable dialog should be shown with the configuration message
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Store Notice'), findsOneWidget);
    expect(
      find.textContaining('is not configured in Google Play Console yet for this app'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Activate Test Mode'), findsOneWidget);

    // Verify dialog is cancelable by tapping Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dialog should be dismissed
    expect(find.byType(AlertDialog), findsNothing);
    // User should NOT be entitled because they cancelled
    expect(settings.isPlusActive, isFalse);
    expect(settings.isProUser, isFalse);
  });

  testWidgets('Store Configuration dialog allows activating test mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Tap the primary subscribe button
    final ctaButton = find.byType(ElevatedButton).first;
    await tester.ensureVisible(ctaButton);
    await tester.tap(ctaButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap Activate Test Mode
    await tester.tap(find.text('Activate Test Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dialog dismissed and entitlement granted
    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.isPlusActive, isTrue);
  });

  testWidgets('Lifetime Pro purchase shows cancelable Store Configuration dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Tap Lifetime Pro button
    final proButton = find.textContaining('Lifetime Pro');
    await tester.ensureVisible(proButton);
    await tester.tap(proButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('Product (${AppConstants.proProductId}) is not configured in Google Play Console yet for this app.'),
      findsOneWidget,
    );

    // Cancel it
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.isProUser, isFalse);
  });
}
