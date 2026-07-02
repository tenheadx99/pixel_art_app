import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pixel_art_app/config/flavor.dart';

/// Admin-panel overrides from Firestore, written by the separate
/// pixel_art_admin project. One `config/{ads,app,economy,announcement}` doc
/// set per flavor under `pixel_art/{flavor}` (flavor doc id =
/// [AppFlavor.name]).
///
/// Everything here is an OVERRIDE layer: a missing doc or field returns null
/// and callers fall through to Remote Config, then hardcoded defaults — so
/// the app behaves exactly as before until the admin saves something.
///
/// After the initial fetch, snapshot listeners keep the values live for the
/// rest of the session (an admin toggling ads applies on the next change,
/// not the next cold start). Firestore's on-disk persistence (default on
/// mobile) means offline launches serve the last-fetched values.
class FirestoreConfigService {
  static final FirestoreConfigService _instance = FirestoreConfigService._();
  factory FirestoreConfigService() => _instance;
  FirestoreConfigService._();

  static const _root = 'pixel_art';
  static const _fetchTimeout = Duration(seconds: 8);

  Map<String, dynamic> _ads = const {};
  Map<String, dynamic> _app = const {};
  Map<String, dynamic> _economy = const {};
  Map<String, dynamic> _announcement = const {};

  final List<StreamSubscription> _subscriptions = [];

  /// Invoked whenever a config doc changes after the initial fetch.
  /// RemoteConfigService uses this to re-derive AppConfig.showAds live.
  void Function()? onChanged;

  CollectionReference<Map<String, dynamic>> get _configCol =>
      FirebaseFirestore.instance
          .collection(_root)
          .doc(currentFlavor.name)
          .collection('config');

  /// Fetches the config docs for the active flavor and attaches live
  /// listeners. Non-critical: any failure leaves the override maps empty
  /// and the app on defaults.
  Future<void> initialize() async {
    try {
      final snaps = await Future.wait([
        _configCol.doc('ads').get(),
        _configCol.doc('app').get(),
        _configCol.doc('economy').get(),
        _configCol.doc('announcement').get(),
      ]).timeout(_fetchTimeout);

      _ads = snaps[0].data() ?? const {};
      _app = snaps[1].data() ?? const {};
      _economy = snaps[2].data() ?? const {};
      _announcement = snaps[3].data() ?? const {};
      developer.log(
        'Firestore config loaded for ${currentFlavor.name}: '
        'ads=${_ads.isNotEmpty} app=${_app.isNotEmpty} '
        'economy=${_economy.isNotEmpty} '
        'announcement=${_announcement.isNotEmpty}',
      );
      _listen();
    } catch (e) {
      developer.log('Firestore config unavailable, using fallbacks: $e');
    }
  }

  void _listen() {
    if (_subscriptions.isNotEmpty) return; // Re-initialize keeps one set.
    void watch(String doc, void Function(Map<String, dynamic>) assign) {
      _subscriptions.add(
        _configCol.doc(doc).snapshots().listen((snap) {
          assign(snap.data() ?? const {});
          onChanged?.call();
        }, onError: (Object e) {
          developer.log('Firestore config listener ($doc) error: $e');
        }),
      );
    }

    watch('ads', (m) => _ads = m);
    watch('app', (m) => _app = m);
    watch('economy', (m) => _economy = m);
    watch('announcement', (m) => _announcement = m);
  }

  // --- Ads overrides ---

  bool? get showAds => _ads['showAds'] as bool?;

  String? get bannerAdUnitId => _nonEmpty(_ads['bannerAdUnitId']);
  String? get interstitialAdUnitId => _nonEmpty(_ads['interstitialAdUnitId']);
  String? get rewardedAdUnitId => _nonEmpty(_ads['rewardedAdUnitId']);
  String? get appOpenAdUnitId => _nonEmpty(_ads['appOpenAdUnitId']);

  int? get interstitialCooldownS => _positive(_ads['interstitialCooldownS']);
  int? get interstitialMinSessionS =>
      _positive(_ads['interstitialMinSessionS']);
  int? get appOpenCooldownS => _positive(_ads['appOpenCooldownS']);

  // --- App overrides ---

  String? get minVersion => _nonEmpty(_app['minVersion']);
  String? get forceUpdateUrl => _nonEmpty(_app['forceUpdateUrl']);

  /// Admin kill-switch: shows a blocking "back soon" screen.
  bool get maintenance => _app['maintenance'] == true;
  String get maintenanceMessage =>
      _nonEmpty(_app['maintenanceMessage']) ??
      'We are doing some quick maintenance.\nPlease check back soon!';

  // --- Announcement banner ---

  bool get announcementEnabled => _announcement['enabled'] == true;
  String get announcementTitle => _nonEmpty(_announcement['title']) ?? '';
  String get announcementMessage => _nonEmpty(_announcement['message']) ?? '';
  String? get announcementLinkUrl => _nonEmpty(_announcement['linkUrl']);

  /// Changes every time the admin saves the announcement; the dismissed
  /// stamp is persisted so an edited announcement shows again.
  int get announcementStamp => (_announcement['stamp'] as num?)?.toInt() ?? 0;

  // --- Economy overrides ---

  /// Override for one economy tunable (keys match the admin panel's
  /// EconomyConfig field names); null = keep the AppConstants default.
  int? economyInt(String key) {
    final v = (_economy[key] as num?)?.toInt();
    return (v == null || v < 0) ? null : v;
  }

  static String? _nonEmpty(Object? v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _positive(Object? v) {
    final n = (v as num?)?.toInt();
    return (n == null || n <= 0) ? null : n;
  }
}
