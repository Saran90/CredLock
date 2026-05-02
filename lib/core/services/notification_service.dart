import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _reminderNotificationId = 1001;
  static const _channelId = 'password_reminders';
  static const _channelName = 'Password Reminders';
  static const _channelDescription = 'Reminders to update your passwords';

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Initialise the plugin and create the Android notification channel.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// Request notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  /// Check current permission status without requesting.
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    } else if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permissions?.isAlertEnabled ?? false;
    }
    return false;
  }

  /// Show (or replace) the reminder notification.
  /// [overdueNames] must be non-empty.
  Future<void> showReminderNotification(List<String> overdueNames) async {
    final body = buildNotificationBody(overdueNames);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      _reminderNotificationId,
      'Password Update Reminder',
      body,
      details,
    );
  }

  /// Cancel the reminder notification.
  Future<void> cancelReminderNotification() async {
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Build the notification body string (extracted as a pure function for testability).
  static String buildNotificationBody(List<String> overdueNames) {
    if (overdueNames.length == 1) {
      return "${overdueNames.first} hasn't been updated in a while.";
    } else if (overdueNames.length <= 4) {
      return "${overdueNames.join(', ')} need updating.";
    } else {
      final listed = overdueNames.take(3).join(', ');
      final remaining = overdueNames.length - 3;
      return '$listed and $remaining more passwords need updating.';
    }
  }
}
