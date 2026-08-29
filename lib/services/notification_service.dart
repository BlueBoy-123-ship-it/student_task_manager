import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Top-level background entry point required for handling notification taps
/// and actions when the app process is completely closed/killed.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Notification action tapped from background/killed state: ${notificationResponse.payload}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Bumping channel IDs to v2 so Android applies the updated notification settings
  static const String _taskChannelId = 'ergobug_task_reminders_v2';
  static const String _taskChannelName = 'Task Reminders';
  static const String _taskChannelDesc = 'Reminders for Ergobug tasks and assignments';

  static const String _testChannelId = 'ergobug_test_notifications_v2';
  static const String _testChannelName = 'Test Notifications';
  static const String _testChannelDesc = 'Test notifications for Ergobug';

  // Brand Accent Color
  static const Color _brandColor = Color(0xFF2563EB);

  bool _initialized = false;
  String _currentTimeZone = 'UTC';

  String get currentTimeZone => _currentTimeZone;

  // =========================================================
  // INITIALIZE NOTIFICATIONS & TIMEZONE
  // =========================================================

  Future<void> initialize() async {
    if (_initialized) return;

    await _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Android notification channels explicitly
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _taskChannelId,
            _taskChannelName,
            description: _taskChannelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: _brandColor,
            showBadge: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _testChannelId,
            _testChannelName,
            description: _testChannelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: _brandColor,
            showBadge: true,
          ),
        );
      }
    }

    _initialized = true;
    debugPrint('NotificationService initialized in timezone: $_currentTimeZone');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped with payload: ${response.payload}');
  }

  // =========================================================
  // TIMEZONE CONFIGURATION
  // =========================================================

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = info.identifier;
      _currentTimeZone = timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone successfully set to: $timeZoneName');
    } catch (e) {
      debugPrint('Failed to set local timezone ($e), falling back to UTC / offset detection');
      try {
        final offset = DateTime.now().timeZoneOffset;
        final matchingLocation = tz.timeZoneDatabase.locations.values.firstWhere(
          (loc) => loc.currentTimeZone.offset == offset.inMilliseconds,
          orElse: () => tz.local,
        );
        tz.setLocalLocation(matchingLocation);
        _currentTimeZone = matchingLocation.name;
        debugPrint('Fallback timezone set to: ${matchingLocation.name}');
      } catch (_) {
        _currentTimeZone = tz.local.name;
      }
    }
  }

  // =========================================================
  // REQUEST NOTIFICATION & EXACT ALARM PERMISSIONS
  // =========================================================

  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final notifGranted =
              await androidPlugin.requestNotificationsPermission();
          final exactGranted =
              await androidPlugin.requestExactAlarmsPermission();
          debugPrint(
            'Android permissions - Notifications: $notifGranted, '
            'Exact Alarms: $exactGranted',
          );
          return notifGranted ?? false;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final darwinPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (darwinPlugin != null) {
          final granted = await darwinPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }

    return false;
  }

  // =========================================================
  // SCHEDULE TASK REMINDER
  // =========================================================

  Future<bool> scheduleTaskReminder({
    required int notificationId,
    required String taskTitle,
    required DateTime reminderDateTime,
    String? body,
    bool weekly = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Convert to local TZDateTime
    var scheduledDate = tz.TZDateTime.from(
      reminderDateTime,
      tz.local,
    );

    final now = tz.TZDateTime.now(tz.local);

    // A weekly reminder that has already passed belongs to the next week.
    if (weekly) {
      while (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }
    } else if (scheduledDate.isBefore(now)) {
      debugPrint('Refusing to schedule past notification: $scheduledDate (Now: $now)');
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      _taskChannelId,
      _taskChannelName,
      channelDescription: _taskChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false, // Prevents aggressive auto-launching

      // Icons and branding
      icon: '@mipmap/launcher_icon',
      color: _brandColor,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),

      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: _brandColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      category: AndroidNotificationCategory.reminder,
      ticker: 'Task Reminder',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'reminder',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Tier 1: Exact Allow While Idle (Accurate delivery without launching the app)
    try {
      await _notifications.zonedSchedule(
        id: notificationId,
        title: 'Task Reminder 🔔',
        body: body ?? '$taskTitle is due soon.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        matchDateTimeComponents:
            weekly ? DateTimeComponents.dayOfWeekAndTime : null,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('ExactAllowWhileIdle reminder scheduled: ID $notificationId at $scheduledDate (tz: $_currentTimeZone)');
      return true;
    } catch (e) {
      debugPrint('Exact alarm scheduling failed ($e), falling back to inexactAllowWhileIdle');
      // Tier 2: Inexact Fallback
      try {
        await _notifications.zonedSchedule(
          id: notificationId,
          title: 'Task Reminder 🔔',
          body: body ?? '$taskTitle is due soon.',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          matchDateTimeComponents:
              weekly ? DateTimeComponents.dayOfWeekAndTime : null,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Inexact fallback reminder scheduled: ID $notificationId at $scheduledDate');
        return true;
      } catch (fallbackError) {
        debugPrint('All reminder scheduling failed: $fallbackError');
        return false;
      }
    }
  }

  // =========================================================
  // TEST NOTIFICATION
  // =========================================================

  Future<void> testNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      _testChannelId,
      _testChannelName,
      channelDescription: _testChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,

      // Icons and branding
      icon: '@mipmap/launcher_icon',
      color: _brandColor,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),

      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: _brandColor,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // 1. Show instant notification to confirm channel works
    await _notifications.show(
      id: 999998,
      title: 'Ergobug Notifications Active 🔔',
      body: 'Notifications and timezone ($_currentTimeZone) are working properly!',
      notificationDetails: details,
    );

    // 2. Schedule test notification for 10 seconds from now
    final testScheduledDate = tz.TZDateTime.now(tz.local).add(
      const Duration(seconds: 10),
    );

    try {
      await _notifications.zonedSchedule(
        id: 999999,
        title: 'Ergobug 10s Timer Test ⏱️',
        body: 'Your scheduled reminder fired accurately!',
        scheduledDate: testScheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('Test reminder scheduled for: $testScheduledDate');
    } catch (e) {
      await _notifications.zonedSchedule(
        id: 999999,
        title: 'Ergobug Test ⏱️',
        body: 'Test reminder fired successfully!',
        scheduledDate: testScheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // =========================================================
  // CANCEL REMINDER
  // =========================================================

  Future<void> cancelTaskReminder(int notificationId) async {
    await _notifications.cancel(id: notificationId);
    debugPrint('Cancelled notification ID: $notificationId');
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}