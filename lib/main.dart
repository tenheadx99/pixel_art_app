import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'l10n/app_localizations.dart';
import 'config/app_constants.dart';
import 'config/app_config.dart';
import 'config/flavor.dart';
import 'firebase_options.dart';
import 'data/services/remote_config_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/database_service.dart';
import 'data/services/ad_service.dart';
import 'data/services/iap_service.dart';
import 'data/services/screenshot_service.dart';
import 'data/services/pixel_converter_service.dart';
import 'data/services/remote_catalog_service.dart';
import 'data/services/daily_pixel_service.dart';
import 'data/services/sound_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/analytics_service.dart';
import 'data/models/pixel_art.dart';
import 'providers/app_settings_provider.dart';
import 'ui/widgets/pixel_grid.dart';
import 'ui/widgets/transitions.dart';
import 'providers/coloring_provider.dart';
import 'providers/gallery_provider.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/force_update_screen.dart';
import 'ui/theme/app_style.dart';

import 'config/version_utils.dart';

// Re-exported: isVersionOlder predates config/version_utils.dart and existing
// callers/tests import it from here.
export 'config/version_utils.dart' show isVersionOlder;

/// True once Firebase has been initialized in [bootstrapApp] so the per-app
/// bootstrap can skip re-initializing it (a second init throws duplicate-app).
bool _firebaseReady = false;

Future<void> main() async {
  // Catch async errors outside the Flutter framework and route them to
  // Crashlytics (when available); the body's own try/catch keeps boot resilient.
  runZonedGuarded(() async {
    await bootstrapApp();
  }, (error, stack) {
    if (_firebaseReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

/// Shared entrypoint logic used by every flavor's `main_*.dart`. The active
/// flavor is resolved from the `FLAVOR` dart-define via [currentFlavor].
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply per-flavor monetization toggles before Firebase/ad/IAP init.
  final flavor = FlavorConfig.current;
  AppConfig.disableAds = !flavor.adsEnabled;
  AppConfig.disableIap = !flavor.iapEnabled;
  AppConfig.disableFullScreenAds = !flavor.fullScreenAdsEnabled;
  AppConfig.disableBannerAds = !flavor.bannerAdsEnabled;

  // Warm the gem fragment shader before any grid paints; without this the
  // first gem frame falls back to a whole-grid CPU bake. Fire-and-forget —
  // PixelGrid retries on its own if this hasn't finished (or failed).
  if (flavor.cellStyle == CellRenderStyle.gem) {
    PixelGrid.preloadGemShader();
  }

  // Initialize Firebase early so Crashlytics can capture errors from the very
  // start. Guarded so a Firebase misconfig never blocks core gameplay.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
    final crashlytics = FirebaseCrashlytics.instance;
    // Framework (build/layout/paint) errors → Crashlytics.
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    // Uncaught errors on the platform dispatcher → Crashlytics.
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e, st) {
    FlutterError.presentError(
      FlutterErrorDetails(exception: e, stack: st, library: 'bootstrap'),
    );
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AppBootstrap());
}

class AppDependencies {
  final LocalStorageService localStorageService;
  final DatabaseService databaseService;
  final IAPService iapService;
  final ScreenshotService screenshotService;
  final SoundService soundService;
  final RemoteCatalogService remoteCatalogService;
  final DailyPixelService dailyPixelService;

  const AppDependencies({
    required this.localStorageService,
    required this.databaseService,
    required this.iapService,
    required this.screenshotService,
    required this.soundService,
    required this.remoteCatalogService,
    required this.dailyPixelService,
  });

  void dispose() {
    iapService.dispose();
    soundService.dispose();
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with WidgetsBindingObserver {
  AppDependencies? _dependencies;
  List<PixelArt> _preMadeArts = [];
  bool _ready = false;
  bool _bootstrapError = false;
  bool _forceUpdateRequired = false;
  String _updateUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App-open ad on return from background (never on cold start); AdService
    // applies the pro/first-session/cooldown caps.
    if (state == AppLifecycleState.resumed && _ready) {
      final storage = _dependencies?.localStorageService;
      // Lifetime Pro or an unexpired Plus subscription both suppress the ad.
      final isPro = (storage?.getBool(AppConstants.proPrefKey) ?? false) ||
          (storage?.getInt(AppConstants.plusExpiryPrefKey) ?? 0) >
              DateTime.now().millisecondsSinceEpoch;
      AdService().showAppOpenAdIfAvailable(isProUser: isPro);
    }
  }

  /// Wraps the real bootstrap with a timeout + catch so the splash always
  /// resolves: either into the app or a recoverable error screen (rather than
  /// freezing forever if a step hangs or a critical service throws).
  Future<void> _bootstrap() async {
    try {
      await _runBootstrap().timeout(const Duration(seconds: 25));
    } catch (e, st) {
      if (_firebaseReady) {
        FirebaseCrashlytics.instance
            .recordError(e, st, reason: 'bootstrap failed');
      }
      if (!mounted) return;
      setState(() => _bootstrapError = true);
    }
  }

  Future<void> _runBootstrap() async {
    final localStorageService = LocalStorageService();
    await localStorageService.init();

    // AdService persists its per-day interstitial cap through this.
    AdService().attachStorage(localStorageService);

    // UMP consent + Mobile Ads SDK init needs neither Remote Config nor IAP
    // (ad unit IDs are read from RC at load time, after the await below), so
    // it runs concurrently with the rest of bootstrap instead of serially.
    final adInitFuture = AdService().initialize();

    // Remote Config + force-update check. Firebase itself is initialized earlier
    // in bootstrapApp(); these are non-critical, so failures fall back to
    // defaults without blocking the app.
    try {
      await AnalyticsService().init(flavorName: currentFlavor.name);
      final remoteConfig = RemoteConfigService();
      remoteConfig.onForceUpdateTriggered = (url) {
        if (mounted) {
          setState(() {
            _forceUpdateRequired = true;
            _updateUrl = url;
          });
        }
      };
      await remoteConfig.initialize();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final minVersion = remoteConfig.minRequiredVersion;

      if (isVersionOlder(currentVersion, minVersion)) {
        _forceUpdateRequired = true;
        _updateUrl = remoteConfig.forceUpdateUrl;
      }
    } catch (e) {
      // Remote Config/PackageInfo are non-critical; continue with defaults.
    }

    final soundService = SoundService();
    await soundService.init();

    // Local-only daily reminders. Initializing here registers the tap handler
    // and captures the launch payload if the app was opened from a reminder;
    // actual (re)scheduling happens once settings load (syncDailyReminders).
    await NotificationService.instance.init();

    final deps = AppDependencies(
      localStorageService: localStorageService,
      databaseService: DatabaseService(),
      iapService: IAPService(),
      screenshotService: ScreenshotService(localStorageService),
      soundService: soundService,
      remoteCatalogService: RemoteCatalogService(localStorageService),
      dailyPixelService: DailyPixelService(localStorageService),
    );

    await deps.iapService.initialize();

    final preMade = await PixelConverterService().loadPreMadeAssets();

    // First-ever session: no full-screen ads (AdService checks this flag).
    final hadFirstSession = localStorageService.getBool('had_first_session');
    localStorageService.setBool('had_first_session', true);

    await adInitFuture;
    AdService()
      ..isFirstSession = !hadFirstSession
      ..loadAppOpenAd()
      // Warm the rewarded cache so the first watch-ad tap shows instantly.
      // Not gated by isFirstSession: rewarded ads are user-initiated.
      ..preloadRewardedAd();

    if (!mounted) return;
    setState(() {
      _dependencies = deps;
      _preMadeArts = preMade;
      _ready = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError) {
      return _AppShell(
        child: _BootstrapErrorScreen(
          onRetry: () {
            setState(() => _bootstrapError = false);
            _bootstrap();
          },
        ),
      );
    }

    if (!_ready || _dependencies == null) {
      return const _AppShell(
        child: SplashScreen(loadingMessage: 'Preparing Pixel Art...'),
      );
    }

    if (_forceUpdateRequired) {
      return _AppShell(
        child: ForceUpdateScreen(updateUrl: _updateUrl),
      );
    }

    return MultiProvider(
      providers: [
        Provider<LocalStorageService>.value(
          value: _dependencies!.localStorageService,
        ),
        Provider<DatabaseService>.value(value: _dependencies!.databaseService),
        Provider<IAPService>.value(value: _dependencies!.iapService),
        Provider<AdService>.value(value: AdService()),
        Provider<SoundService>.value(value: _dependencies!.soundService),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) {
            final provider = AppSettingsProvider(
              _dependencies!.localStorageService,
            );
            // Top up the on-device reminder schedule once settings are loaded.
            provider.loadSettings().then((_) => provider.syncDailyReminders());
            provider.listenToIAP(_dependencies!.iapService.purchaseStream);
            // Re-deliver past purchases (e.g. Pro after a reinstall); must
            // run after listenToIAP so the restored events are observed.
            _dependencies!.iapService.restorePurchases();
            return provider;
          },
        ),
        ChangeNotifierProvider<GalleryProvider>(
          create: (context) {
            final provider = GalleryProvider(
              _dependencies!.localStorageService,
              _dependencies!.databaseService,
              _dependencies!.remoteCatalogService,
              _dependencies!.dailyPixelService,
            );
            provider.loadCatalog(_preMadeArts);
            // Bundled art shows immediately; the admin-published Firestore
            // catalog (new artworks + overrides) merges in when the fetch
            // lands. Unchanged catalogs are served from Firestore's local
            // cache, so this is one doc read on most launches.
            final remoteCatalog = _dependencies!.remoteCatalogService;
            remoteCatalog.fetchCatalog(_preMadeArts).then((merged) async {
              // Runs on both outcomes: cached remote artworks the user has
              // progress on must survive a failed fetch (offline) too. The
              // catch keeps a surprise throw in this unawaited chain from
              // surfacing as a fatal uncaught async error — the bundled
              // catalog is already showing, so degrading silently is correct.
              try {
                final catalog = await remoteCatalog
                    .withRestoredCachedArts(merged ?? _preMadeArts);
                provider.updateCatalog(
                  catalog,
                  retiredIds: remoteCatalog.retiredIds,
                );
                // Pin today's daily only once the merged catalog is in, so an
                // admin-scheduled remote artwork can actually be found.
                provider.resolveDailyArt();
              } catch (_) {}
            });
            return provider;
          },
        ),
        ChangeNotifierProvider<ColoringProvider>(
          create: (context) =>
              ColoringProvider(_dependencies!.localStorageService),
        ),
      ],
      child: const _AppShellWithDeps(),
    );
  }
}

/// Shown when bootstrap fails or times out, instead of an endless splash.
/// Offers a retry so a transient failure (e.g. cold start while offline) is
/// recoverable without a force-kill.
class _BootstrapErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _BootstrapErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'Something went wrong while starting up.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  final Widget child;

  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlavorConfig.current.appName,
      debugShowCheckedModeBanner: false,
      theme: AppStyle.lightTheme(),
      darkTheme: AppStyle.darkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}

class _AppShellWithDeps extends StatelessWidget {
  const _AppShellWithDeps();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: FlavorConfig.current.appName,
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppStyle.lightTheme(),
          darkTheme: AppStyle.darkTheme(),
          locale: settings.appLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [AnalyticsService().observer],
          home: const _IntroFlow(),
        );
      },
    );
  }
}

class _IntroFlow extends StatelessWidget {
  const _IntroFlow();

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      canContinue: true,
      displayDuration: const Duration(seconds: 2),
      loadingMessage: 'Loading your next canvas...',
      onFinished: () {
        Navigator.of(context).pushReplacement(
          fadeThroughRoute(const HomeScreen(), name: 'home'),
        );
      },
    );
  }
}
