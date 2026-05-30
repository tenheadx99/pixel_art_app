import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/services/remote_config_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/database_service.dart';
import 'data/services/ad_service.dart';
import 'data/services/iap_service.dart';
import 'data/services/screenshot_service.dart';
import 'data/services/pixel_converter_service.dart';
import 'data/models/pixel_art.dart';
import 'providers/app_settings_provider.dart';
import 'providers/coloring_provider.dart';
import 'providers/gallery_provider.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  const AppDependencies({
    required this.localStorageService,
    required this.databaseService,
    required this.iapService,
    required this.screenshotService,
  });

  void dispose() {
    iapService.dispose();
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  AppDependencies? _dependencies;
  List<PixelArt> _preMadeArts = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final localStorageService = LocalStorageService();
    await localStorageService.init();

    // Initialize Firebase and Remote Config before setting up dependencies and ads
    try {
      await Firebase.initializeApp();
      await RemoteConfigService().initialize();
    } catch (e) {
      // Safe fallback if Firebase is not fully configured yet
    }

    final deps = AppDependencies(
      localStorageService: localStorageService,
      databaseService: DatabaseService(),
      iapService: IAPService(),
      screenshotService: ScreenshotService(localStorageService),
    );

    await deps.iapService.initialize();

    final preMade = await PixelConverterService().loadPreMadeAssets();

    AdService().initialize();

    if (!mounted) return;
    setState(() {
      _dependencies = deps;
      _preMadeArts = preMade;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _dependencies == null) {
      return const _AppShell(
        child: SplashScreen(loadingMessage: 'Preparing Pixel Art...'),
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
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) {
            final provider = AppSettingsProvider(
              _dependencies!.localStorageService,
            );
            provider.loadSettings();
            provider.listenToIAP(_dependencies!.iapService.purchaseStream);
            return provider;
          },
        ),
        ChangeNotifierProvider<GalleryProvider>(
          create: (context) {
            final provider = GalleryProvider(
              _dependencies!.localStorageService,
              _dependencies!.databaseService,
            );
            provider.loadCatalog(_preMadeArts);
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

class _AppShell extends StatelessWidget {
  final Widget child;

  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PixelyArt',
      debugShowCheckedModeBanner: false,
      theme: AppStyle.lightTheme(),
      darkTheme: AppStyle.darkTheme(),
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
          title: 'PixelyArt',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppStyle.lightTheme(),
          darkTheme: AppStyle.darkTheme(),
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
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      },
    );
  }
}
