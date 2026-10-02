import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/services/local_storage_service.dart';
import 'package:pixel_art_app/data/services/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Manages dynamic in-app update prompts and remote app configuration,
/// synchronized in real-time from Firestore (`pixel_art/{flavor}/config/app`)
/// with automatic fallback to Firebase Remote Config.
class AppConfigService extends ChangeNotifier {
  static final AppConfigService _instance = AppConfigService._();
  factory AppConfigService() => _instance;
  AppConfigService._();

  static const String _updateClickedVersionPrefKey = 'update_clicked_version';
  LocalStorageService? _storage;
  String? _updateClickedVersion;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String _currentAppVersion = '1.0.0';
  String _packageName = 'com.tenhead.pixelyart';

  String? _minVersion;
  String? _targetVersion;
  String? _remoteUpdateUrl;
  String? _updateTitle;
  String? _releaseNotes;
  bool _updateEnabled = true;

  /// Callback fired when an immediate blocking force-update is required.
  void Function(String updateUrl, String minVersion)? onForceUpdateRequired;

  // Session-scoped dismissal: resets on every cold start / app launch
  bool _isDismissedThisSession = false;

  String get currentAppVersion => _currentAppVersion;
  String get packageName => _packageName;
  bool get isDismissedThisSession => _isDismissedThisSession;
  String? get updateClickedVersion => _updateClickedVersion;

  String get minVersion {
    if (_minVersion != null && _minVersion!.isNotEmpty) {
      return _minVersion!;
    }
    try {
      final rcMin = RemoteConfigService().minRequiredVersion;
      if (rcMin.isNotEmpty && rcMin != '1.0.0') {
        return rcMin;
      }
    } catch (_) {}
    return '';
  }

  String get targetVersion {
    if (_targetVersion != null && _targetVersion!.isNotEmpty) {
      return _targetVersion!;
    }
    final min = minVersion;
    if (min.isNotEmpty && min != '1.0.0') {
      return min;
    }
    return '';
  }

  String get updateTitle {
    if (_updateTitle != null && _updateTitle!.trim().isNotEmpty) {
      return _updateTitle!.trim();
    }
    return 'Exciting Update Available!';
  }

  String get updateUrl {
    if (_remoteUpdateUrl != null && _remoteUpdateUrl!.trim().isNotEmpty) {
      return _remoteUpdateUrl!.trim();
    }
    try {
      final rcUrl = RemoteConfigService().forceUpdateUrl;
      if (rcUrl.trim().isNotEmpty) {
        return rcUrl.trim();
      }
    } catch (_) {}
    return 'https://play.google.com/store/apps/details?id=$_packageName';
  }

  List<String> get releaseNotesList {
    if (_releaseNotes != null && _releaseNotes!.trim().isNotEmpty) {
      return _releaseNotes!
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) {
            // Strip leading bullet dash or dot if present for uniform formatting
            if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
              return line.substring(1).trim();
            }
            return line;
          })
          .toList();
    }

    // Default curated release highlights if not explicitly provided
    return const [
      'New beautiful pixel artworks added',
      'Smoother coloring controls and improved performance',
      'Bug fixes and stability enhancements',
    ];
  }

  /// Whether an update is available according to Admin Firestore or Remote Config
  bool get isUpdateAvailable {
    if (!_updateEnabled) return false;
    final target = targetVersion;
    if (target.isEmpty) return false;
    return isVersionOlder(_currentAppVersion, target);
  }

  /// Whether a blocking, mandatory force-update is required
  bool get isForceUpdateRequired {
    if (!_updateEnabled) return false;
    final min = minVersion;
    if (min.isEmpty) return false;
    return isVersionOlder(_currentAppVersion, min);
  }

  /// Whether the UI card should be rendered on the Home screen.
  /// Hides on click of update button (session dismissal), hides if app version
  /// is updated (isUpdateAvailable == false), and is shown if app version is not updated.
  bool get shouldShowUpdateCard => isUpdateAvailable && !_isDismissedThisSession;

  /// Attach the persistent [LocalStorageService] instance to retain dismissal and update choices.
  void attachStorage(LocalStorageService storage) {
    _storage = storage;
    final saved = storage.getString(_updateClickedVersionPrefKey);
    if (saved.isNotEmpty) {
      _updateClickedVersion = saved;
    }
  }

  /// Initializes the service: reads app version, fetches Firestore config,
  /// attaches real-time snapshot listener, and checks Remote Config.
  Future<void> initialize({LocalStorageService? storage}) async {
    if (storage != null) {
      attachStorage(storage);
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_updateClickedVersionPrefKey);
        if (saved != null && saved.isNotEmpty) {
          _updateClickedVersion = saved;
        }
      } catch (_) {}
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;
      _packageName = packageInfo.packageName;
    } catch (e) {
      developer.log('AppConfigService: failed to read PackageInfo: $e');
    }

    final flavorId = currentFlavor.name;
    final docPath = 'pixel_art/$flavorId/config/app';

    // 1. Initial Firestore fetch
    try {
      final snap = await _db.doc(docPath).get();
      if (snap.exists && snap.data() != null) {
        _applyFirestoreData(snap.data()!);
      }
    } catch (e) {
      developer.log('AppConfigService: Firestore read error: $e');
    }

    // 2. Real-time snapshot updates from Admin app
    try {
      _db.doc(docPath).snapshots().listen(
        (snap) {
          if (snap.exists && snap.data() != null) {
            _applyFirestoreData(snap.data()!);
            notifyListeners();
          }
        },
        onError: (e) {
          developer.log('AppConfigService: snapshot error: $e');
        },
      );
    } catch (e) {
      developer.log('AppConfigService: snapshot listener setup error: $e');
    }

    // 3. Fallback or sync from Remote Config
    final rcService = RemoteConfigService();
    rcService.onForceUpdateTriggered = (url) {
      if (url.isNotEmpty) _remoteUpdateUrl = url;
      if (isForceUpdateRequired) {
        onForceUpdateRequired?.call(updateUrl, minVersion);
      }
      notifyListeners();
    };

    notifyListeners();
  }

  void _applyFirestoreData(Map<String, dynamic> data) {
    _minVersion = data['minVersion'] as String?;
    _targetVersion = data['latestVersion'] as String? ?? _minVersion;
    _remoteUpdateUrl = data['updateUrl'] as String? ??
        data['forceUpdateUrl'] as String?;
    _updateTitle = data['updateTitle'] as String?;
    _releaseNotes = data['releaseNotes'] as String?;
    if (data.containsKey('updateEnabled')) {
      _updateEnabled = data['updateEnabled'] == true;
    } else {
      // If minVersion or latestVersion is specified, default to enabled
      _updateEnabled = (_targetVersion != null && _targetVersion!.isNotEmpty) ||
          (_minVersion != null && _minVersion!.isNotEmpty);
    }

    if (isForceUpdateRequired) {
      onForceUpdateRequired?.call(updateUrl, minVersion);
    }
  }

  /// Dismiss the update card for the current app session.
  /// It will reappear automatically on the next cold start / launch.
  void dismissForSession() {
    _isDismissedThisSession = true;
    notifyListeners();
  }

  /// Refreshes the currently installed app version from the platform.
  /// Call this when the app resumes from the background (e.g. after returning from Play Store).
  Future<void> refreshVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final oldVersion = _currentAppVersion;
      _currentAppVersion = packageInfo.version;
      _packageName = packageInfo.packageName;
      if (oldVersion != _currentAppVersion) {
        notifyListeners();
      }
    } catch (e) {
      developer.log('AppConfigService: failed to refresh PackageInfo: $e');
    }
  }

  /// Marks that the user has tapped to update the app for [version] (or [targetVersion]).
  /// Persists this state so the update UI component does not prompt again for this version.
  void markUpdateClicked([String? version]) {
    final v = (version != null && version.isNotEmpty) ? version : targetVersion;
    if (v.isNotEmpty) {
      _updateClickedVersion = v;
      _isDismissedThisSession = true;
      try {
        if (_storage != null) {
          _storage!.setString(_updateClickedVersionPrefKey, v);
        } else {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(_updateClickedVersionPrefKey, v);
          }).catchError((_) {});
        }
      } catch (e) {
        developer.log('AppConfigService: failed to persist updateClickedVersion: $e');
      }
      notifyListeners();
    }
  }

  /// Checks if the user has already initiated update for the specified version.
  bool isUpdateClickedFor(String version) {
    if (version.isEmpty) return false;
    return _updateClickedVersion == version;
  }

  @visibleForTesting
  void setCurrentAppVersionForTesting(String version) {
    _currentAppVersion = version;
    notifyListeners();
  }

  @visibleForTesting
  void setTargetVersionForTesting(String? version) {
    _targetVersion = version;
    notifyListeners();
  }

  @visibleForTesting
  void resetStateForTesting() {
    _isDismissedThisSession = false;
    _updateClickedVersion = null;
    notifyListeners();
  }

  /// Opens the store update page via market URL scheme or fallback web URL.
  Future<void> launchStore() async {
    final marketUri = Uri.parse('market://details?id=$_packageName');
    final webUri = Uri.parse(updateUrl);

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      developer.log('AppConfigService: failed to launch update url: $e');
    }
  }

  /// SemVer comparator: returns true if [current] is strictly older than [target].
  static bool isVersionOlder(String current, String target) {
    if (target.trim().isEmpty) return false;
    final currentClean = current.split('+')[0].trim();
    final targetClean = target.split('+')[0].trim();

    final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final targetParts = targetClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (targetParts.length < 3) {
      targetParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }
    return false;
  }
}
