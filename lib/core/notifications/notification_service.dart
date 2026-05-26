import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Service for scheduling and managing local task notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService._internal();

  /// Initialize the notification plugin. Must be called early in app startup.
  ///
  /// [onNotificationTapped] is called when a notification is tapped. The payload
  /// contains the task ID string.
  Future<void> init({void Function(String? taskId)? onNotificationTapped}) async {
    _onNotificationTapped = onNotificationTapped;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    await _createNotificationChannel();
    _initialized = true;
  }

  /// Returns true if the notification plugin has been initialized.
  bool get isInitialized => _initialized;

  /// Create Android notification channel.
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Notifications for upcoming task deadlines',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Callback for notification tap - set via init().
  static void Function(String? taskId)? _onNotificationTapped;

  /// Handle notification tap - forwards to the configured callback.
  void _handleNotificationTap(NotificationResponse response) {
    log('Notification tapped: ${response.payload}');
    _onNotificationTapped?.call(response.payload);
  }

  /// Schedule a notification for a task due date.
  Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? taskId,
  }) async {
    if (!_initialized) return;
    // Don't schedule past notifications
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming task deadlines',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );
  }

  /// Cancel a specific notification.
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// Show an immediate notification (for testing).
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }
}
