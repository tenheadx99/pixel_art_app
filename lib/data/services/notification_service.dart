import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Background FCM message entry point. Must be top-level and pragma annotated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
    'FCM background message received: ${message.messageId}',
    name: 'NotificationService',
  );
}

/// Service managing both local daily/streak reminders and remote FCM push notifications.
///
/// Features:
/// - Local daily morning & evening scheduled reminders
/// - 7 PM streak-at-risk notifications
/// - Firebase Cloud Messaging (FCM) topic subscription (flavor + all)
/// - Foreground & background push notifications
/// - Rich BigPictureStyle notifications with downloaded network images
/// - Deep-link routing to Daily Art, specific Artwork, Category, or Diamond Shop
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'daily_reminders';
  static const String _channelName = 'Daily Reminders';
  static const String _channelDescription =
      'Gentle daily nudges to relax with a fresh pixel canvas.';

  /// Payload attached to every reminder so taps can be routed to Daily Art.
  static const String dailyArtPayload = 'open_daily_art';

  /// Morning reminders fire at 09:00 local time.
  static const int _morningHour = 9;
  static const int _morningMinute = 0;

  /// Evening reminders fire at 20:00 local time (the recommended wind-down
  /// window for a calming, therapeutic activity).
  static const int _eveningHour = 20;
  static const int _eveningMinute = 0;

  /// How many days ahead we queue notifications. We re-schedule on every app
  /// launch, so this only needs to cover a realistic "didn't open the app"
  /// gap before the queue is topped up again.
  static const int _daysAhead = 14;

  // Distinct id ranges keep morning/evening days from colliding.
  static const int _morningIdBase = 1000;
  static const int _eveningIdBase = 2000;

  /// Rotated by day-of-year so the same prompt doesn't repeat back-to-back.
  static const List<String> _morningMessages = [
    'Start your morning with a relaxing cup of coffee and a fresh pixel canvas. ☕🎨',
    'Good morning! A brand-new Daily Pixel is ready to brighten your day. 🌅✨',
    'Ease into the day — a few calm taps and a blank canvas are waiting. 🧘🎨',
    'Rise and shine! Color your mornings, one pixel at a time. 🌞🖌️',
    'A peaceful start: pour a coffee and fill in today\'s pixel art. ☕🟦',
  ];

  static const List<String> _eveningMessages = [
    'Unwind after a busy day. Satisfying sounds and a calm canvas are waiting for you. 🧘‍♀️✨',
    'Wind down tonight with a relaxing pixel-by-pixel escape. 🌙🎨',
    'De-stress before bed — let the colors melt the day away. 💤🖌️',
    'Evening calm: your Daily Pixel is the perfect way to relax. 🌆✨',
    'Take a mindful break. A soothing canvas is ready for you tonight. 🕯️🎨',
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set when a reminder or push is tapped targeting Daily Art.
  final ValueNotifier<bool> dailyArtRequested = ValueNotifier<bool>(false);

  /// Set when a push notification targeting a specific artwork is tapped.
  final ValueNotifier<String?> pendingArtworkId = ValueNotifier<String?>(null);

  /// Set when a push notification targeting a category is tapped.
  final ValueNotifier<String?> pendingCategory = ValueNotifier<String?>(null);

  /// Set when a push notification targeting the diamond shop is tapped.
  final ValueNotifier<bool> pendingShopRequested = ValueNotifier<bool>(false);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (e) {
        // Fall back to UTC if the device timezone can't be resolved; reminders
        // still fire, just anchored to UTC wall-clock.
        developer.log(
          'Could not resolve local timezone, using UTC',
          name: 'NotificationService',
          error: e,
        );
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const darwinSettings = DarwinInitializationSettings(
        // Permissions are requested explicitly when the user enables reminders or on app start.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel on Android explicitly with high priority
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      // If the app was launched cold by tapping a notification, route according to payload.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null) {
          _routePayload(payload);
        }
      }

      _initialized = true;
    } catch (e, stackTrace) {
      developer.log(
        'NotificationService initialization failed',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _routePayload(payload);
    }
  }

  void _routePayload(String payload) {
    if (payload == dailyArtPayload) {
      dailyArtRequested.value = true;
    } else if (payload.startsWith('artwork:')) {
      pendingArtworkId.value = payload.substring('artwork:'.length);
    } else if (payload.startsWith('category:')) {
      pendingCategory.value = payload.substring('category:'.length);
    } else if (payload == 'shop') {
      pendingShopRequested.value = true;
    }
  }

  /// Initializes Firebase Cloud Messaging for live push broadcasts, topic subscription,
  /// and rich BigPictureStyle foreground alerts.
  Future<void> initPushNotifications(String flavorId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permissions (critical on Android 13+ and iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      developer.log(
        'FCM permission status: ${settings.authorizationStatus}',
        name: 'NotificationService',
      );

      // Subscribe to broadcast topics for this flavor and all flavors
      await messaging.subscribeToTopic('pixel_art_all');
      await messaging.subscribeToTopic('pixel_art_$flavorId');
      developer.log(
        'Subscribed to FCM topics: pixel_art_all, pixel_art_$flavorId',
        name: 'NotificationService',
      );

      // Listen for foreground push messages
      _setupForegroundPushListener();

      // Listen for background push tap open events
      _setupPushTapListeners();
    } catch (e, st) {
      developer.log(
        'Push notification setup skipped or failed: $e',
        name: 'NotificationService',
        stackTrace: st,
      );
    }
  }

  void _setupForegroundPushListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      developer.log(
        'Received FCM foreground message: ${message.messageId}',
        name: 'NotificationService',
      );

      final notification = message.notification;
      final title = notification?.title ??
          message.data['title'] ??
          'New Artwork Alert! 🎨';
      final body = notification?.body ??
          message.data['body'] ??
          'Tap to discover and color brand new pixel art!';
      final imageUrl = notification?.android?.imageUrl ??
          notification?.apple?.imageUrl ??
          message.data['image'] ??
          message.data['imageUrl'];

      final action = message.data['action'] ?? 'daily_art';
      final actionData = message.data['actionData'] ?? '';
      String payload = dailyArtPayload;
      if (action == 'artwork' && actionData.isNotEmpty) {
        payload = 'artwork:$actionData';
      } else if (action == 'category' && actionData.isNotEmpty) {
        payload = 'category:$actionData';
      } else if (action == 'shop') {
        payload = 'shop';
      }

      final details = await _buildPushNotificationDetails(
        imageUrl: imageUrl,
        title: title,
        body: body,
      );

      final id = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    });
  }

  void _setupPushTapListeners() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageOpened);

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleRemoteMessageOpened(message);
      }
    });
  }

  void _handleRemoteMessageOpened(RemoteMessage message) {
    developer.log(
      'FCM Notification tapped with action: ${message.data['action']}',
      name: 'NotificationService',
    );
    final action = message.data['action'];
    final actionData = message.data['actionData'];

    if (action == 'artwork' && actionData != null && actionData.isNotEmpty) {
      pendingArtworkId.value = actionData;
    } else if (action == 'category' &&
        actionData != null &&
        actionData.isNotEmpty) {
      pendingCategory.value = actionData;
    } else if (action == 'shop') {
      pendingShopRequested.value = true;
    } else {
      dailyArtRequested.value = true;
    }
  }

  Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      developer.log(
        'Failed to download notification image: $url',
        name: 'NotificationService',
        error: e,
      );
    }
    return null;
  }

  Future<NotificationDetails> _buildPushNotificationDetails({
    String? imageUrl,
    String? title,
    String? body,
  }) async {
    String? bigPicturePath;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final cleanUrl = imageUrl.trim();
      final ext = cleanUrl.contains('.')
          ? cleanUrl.split('.').last.split('?').first
          : 'png';
      final safeExt = (ext.length <= 4 && !ext.contains('/')) ? ext : 'png';
      final fileName =
          'fcm_img_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      bigPicturePath = await _downloadAndSaveFile(cleanUrl, fileName);
    }

    final AndroidNotificationDetails android;
    if (bigPicturePath != null) {
      final bigPictureStyle = BigPictureStyleInformation(
        FilePathAndroidBitmap(bigPicturePath),
        largeIcon: FilePathAndroidBitmap(bigPicturePath),
        contentTitle: title,
        summaryText: body,
        hideExpandedLargeIcon: true,
      );
      android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: bigPictureStyle,
        icon: '@mipmap/launcher_icon',
      );
    } else {
      android = const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );
    }

    final DarwinNotificationDetails darwin;
    if (bigPicturePath != null) {
      darwin = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: [
          DarwinNotificationAttachment(bigPicturePath),
        ],
      );
    } else {
      darwin = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    }

    return NotificationDetails(android: android, iOS: darwin);
  }

  /// Asks the OS for permission to post notifications. Returns true if granted.
  /// Call this when the user turns the reminders toggle on.
  Future<bool> requestPermissions() async {
    if (!_initialized) await init();
    try {
      if (Platform.isAndroid) {
        final android =
            _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // POST_NOTIFICATIONS is a runtime permission on Android 13+; older
        // versions return true here without a prompt.
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final ios =
            _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      developer.log(
        'requestPermissions failed',
        name: 'NotificationService',
        error: e,
      );
    }
    return false;
  }

  /// Cancels any queued reminders and schedules a fresh batch of morning and
  /// evening reminders for the next [_daysAhead] days. Safe to call on every
  /// app launch — it keeps the on-device queue topped up with rotating copy.
  Future<void> scheduleDailyReminders() async {
    if (!_initialized) await init();
    await cancelAll();

    final details = _notificationDetails();
    final now = tz.TZDateTime.now(tz.local);

    for (int day = 0; day < _daysAhead; day++) {
      await _scheduleOne(
        id: _morningIdBase + day,
        when: _instanceFor(now, _morningHour, _morningMinute, day),
        title: 'Your Daily Pixel is ready 🎨',
        body: _messageFor(_morningMessages, day),
        details: details,
      );
      await _scheduleOne(
        id: _eveningIdBase + day,
        when: _instanceFor(now, _eveningHour, _eveningMinute, day),
        title: 'Time to relax 🌙',
        body: _messageFor(_eveningMessages, day),
        details: details,
      );
    }
  }

  Future<void> _scheduleOne({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    // Skip slots that have already passed today so we don't fire immediately.
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: dailyArtPayload,
      );
    } catch (e) {
      developer.log(
        'Failed to schedule reminder $id',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Builds the local fire time [day] days from now at the given hour/minute.
  tz.TZDateTime _instanceFor(
    tz.TZDateTime now,
    int hour,
    int minute,
    int dayOffset,
  ) {
    final base = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    return base.add(Duration(days: dayOffset));
  }

  String _messageFor(List<String> pool, int dayOffset) {
    final now = tz.TZDateTime.now(tz.local);
    // Anchor rotation to the absolute day so morning/evening pools advance in
    // step and the text changes day to day rather than per-app-launch.
    final dayIndex = now.add(Duration(days: dayOffset)).day;
    return pool[dayIndex % pool.length];
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/launcher_icon',
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      developer.log(
        'cancelAll failed',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Streak-at-Risk Notification
  // ---------------------------------------------------------------------------

  /// ID range for streak-at-risk reminders, distinct from morning/evening.
  static const int _streakIdBase = 3000;

  /// Hour (19:00 / 7 PM) when the streak-at-risk reminder fires.
  static const int _streakRiskHour = 19;
  static const int _streakRiskMinute = 0;

  /// Streak-aware notification copy, rotated by day.
  static const List<String> _streakRiskMessages = [
    "Don't break your {streak}-day streak! Just one artwork to keep it alive. 🔥",
    "Your {streak}-day streak is at risk! A quick color session saves it. 🎨",
    "🔥 {streak} days strong — don't stop now! Complete any artwork today.",
    "Almost there! Keep your {streak}-day streak going with a few pixels. ✨",
    "Your streak flame needs you! Color one piece to save {streak} days of progress. 🕯️",
  ];

  /// Schedules a 7 PM "streak at risk" notification for today (and the next
  /// [_daysAhead] days) if the user has an active streak. Call this on app
  /// launch after [scheduleDailyReminders]. Pass [currentStreak] > 0 and
  /// [todayCompleted] = false to schedule; otherwise this is a no-op.
  ///
  /// If the user opens the app and has already completed today, the streak
  /// notification is not needed and will be skipped.
  Future<void> scheduleStreakAtRiskReminder({
    required int currentStreak,
    required bool todayCompleted,
  }) async {
    if (!_initialized) await init();
    if (currentStreak <= 0 || todayCompleted) {
      // No active streak or already safe today — cancel any queued streak alerts
      for (int day = 0; day < _daysAhead; day++) {
        try {
          await _plugin.cancel(id: _streakIdBase + day);
        } catch (_) {}
      }
      return;
    }

    final details = _notificationDetails();
    final now = tz.TZDateTime.now(tz.local);

    for (int day = 0; day < _daysAhead; day++) {
      final msg = _streakRiskMessages[
              (now.add(Duration(days: day)).day) % _streakRiskMessages.length]
          .replaceAll('{streak}', '$currentStreak');
      await _scheduleOne(
        id: _streakIdBase + day,
        when: _instanceFor(now, _streakRiskHour, _streakRiskMinute, day),
        title: '🔥 Your streak is at risk!',
        body: msg,
        details: details,
      );
    }
  }
}
