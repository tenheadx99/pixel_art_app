import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the daily "come back and color" reminders entirely on-device — no
/// push server required. Two reminders fire per day (a morning nudge and an
/// evening wind-down), each with copy that matches the time of day and rotates
/// across a small pool so it never reads like robotic spam.
///
/// Tapping a reminder deep-links to the Daily Art canvas: the tap sets
/// [dailyArtRequested], which the home screen observes to open the daily art.
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

  /// Set when a reminder is tapped (foreground/background or cold start). The
  /// home screen listens and opens the Daily Art canvas, then resets it.
  final ValueNotifier<bool> dailyArtRequested = ValueNotifier<bool>(false);

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
        // Permissions are requested explicitly when the user enables reminders.
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

      // If the app was launched cold by tapping a reminder, route to Daily Art.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        if (launchDetails?.notificationResponse?.payload == dailyArtPayload) {
          dailyArtRequested.value = true;
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
    if (response.payload == dailyArtPayload) {
      dailyArtRequested.value = true;
    }
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
}
