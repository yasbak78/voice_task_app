import 'dart:async';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Notification action identifiers.
class NotificationActionIds {
  static const String complete = 'action_complete';
  static const String snooze = 'action_snooze';
  static const String dismiss = 'action_dismiss';
}

/// Callback type for notification actions (complete, snooze, dismiss).
typedef NotificationActionCallback = void Function(
  String actionId,
  String? taskId,
);

/// Available reminder sound options.
enum ReminderSound {
  silent('Silent', null, 'no_sound'),
  gentlePing('Gentle Ping', 'gentle_ping', 'soft_tone'),
  classicBell('Classic Bell', 'classic_bell', 'bell'),
  urgentBeep('Urgent Beep', 'urgent_beep', 'urgent'),
  melody('Melody', 'melody', 'melody'),
  completionChime('Completion Chime', 'completion_chime', 'completion_chime'),
  successPing('Success Ping', 'success_ping', 'success_ping'),
  gentleComplete('Gentle Complete', 'gentle_complete', 'gentle_complete'),
  systemDefault('System Default', null, 'system_default');

  const ReminderSound(this.label, this.androidSoundName, this.id);
  final String label;
  final String? androidSoundName; // null = use channel default
  final String id;

  static ReminderSound fromId(String id) {
    return ReminderSound.values.firstWhere(
      (s) => s.id == id,
      orElse: () => ReminderSound.systemDefault,
    );
  }
}

/// Service for scheduling and managing local task notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  NotificationActionCallback? _onAction;

  NotificationService._internal();

  /// Initialize the notification plugin. Must be called early in app startup.
  ///
  /// [onNotificationTapped] is called when a notification is tapped. The payload
  /// contains the task ID string.
  /// [onAction] is called when a notification action button is pressed.
  Future<void> init({
    void Function(String? taskId)? onNotificationTapped,
    NotificationActionCallback? onAction,
  }) async {
    _onNotificationTapped = onNotificationTapped;
    _onAction = onAction;
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

    await _createAllNotificationChannels();
    _initialized = true;
  }

  /// Returns true if the notification plugin has been initialized.
  bool get isInitialized => _initialized;

  /// Create all notification channels with different sounds.
  Future<void> _createAllNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Default channel (system sound)
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'task_reminders_default',
      'Task Reminders - Default',
      description: 'Standard task reminders with system sound',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    // Gentle ping channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_gentle',
      'Task Reminders - Gentle Ping',
      description: 'Soft, single-tone reminder',
      importance: Importance.defaultImportance,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('gentle_ping'),
      enableVibration: false,
    ));

    // Classic bell channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_bell',
      'Task Reminders - Classic Bell',
      description: 'Two-tone bell reminder',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('classic_bell'),
      enableVibration: true,
    ));

    // Urgent beep channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_urgent',
      'Task Reminders - Urgent',
      description: 'Repeating urgent beep',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('urgent_beep'),
      enableVibration: true,
      showBadge: true,
    ));

    // Melody channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_melody',
      'Task Reminders - Melody',
      description: 'Pleasant ascending melody',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('melody'),
      enableVibration: false,
    ));

    // Completion chime channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_completion',
      'Task Reminders - Completion Chime',
      description: 'Three-note ascending chime for task completion',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('completion_chime'),
      enableVibration: true,
    ));

    // Success ping channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_success',
      'Task Reminders - Success Ping',
      description: 'Short crisp success tone',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('success_ping'),
      enableVibration: true,
    ));

    // Gentle complete channel
    await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
      'task_reminders_gentle_complete',
      'Task Reminders - Gentle Complete',
      description: 'Soft warm completion tone',
      importance: Importance.defaultImportance,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('gentle_complete'),
      enableVibration: false,
    ));

    // Silent channel
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'task_reminders_silent',
      'Task Reminders - Silent',
      description: 'Vibration only, no sound',
      importance: Importance.low,
      playSound: false,
      enableVibration: true,
    ));
  }

  /// Get the channel ID for a specific reminder sound.
  String _getChannelIdForSound(ReminderSound sound) {
    return switch (sound) {
      ReminderSound.silent => 'task_reminders_silent',
      ReminderSound.gentlePing => 'task_reminders_gentle',
      ReminderSound.classicBell => 'task_reminders_bell',
      ReminderSound.urgentBeep => 'task_reminders_urgent',
      ReminderSound.melody => 'task_reminders_melody',
      ReminderSound.completionChime => 'task_reminders_completion',
      ReminderSound.successPing => 'task_reminders_success',
      ReminderSound.gentleComplete => 'task_reminders_gentle_complete',
      ReminderSound.systemDefault => 'task_reminders_default',
    };
  }

  /// Callback for notification tap - set via init().
  static void Function(String? taskId)? _onNotificationTapped;

  /// Handle notification tap - forwards to the configured callback.
  void _handleNotificationTap(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      log('Notification action: $actionId for task: ${response.payload}');
      _onAction?.call(actionId, response.payload);
      return;
    }
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
    ReminderSound sound = ReminderSound.systemDefault,
  }) async {
    if (!_initialized) return;
    // Don't schedule past notifications
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    final channelId = _getChannelIdForSound(sound);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Task Reminders - ${sound.label}',
      channelDescription: 'Task reminder with ${sound.label.toLowerCase()} sound',
      importance: switch (sound) {
        ReminderSound.urgentBeep => Importance.max,
        ReminderSound.silent => Importance.low,
        _ => Importance.high,
      },
      priority: switch (sound) {
        ReminderSound.urgentBeep => Priority.max,
        ReminderSound.silent => Priority.low,
        _ => Priority.high,
      },
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActionIds.complete,
          '✓ Complete',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActionIds.snooze,
          '⏰ Snooze 15m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActionIds.dismiss,
          '✕ Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
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

  /// Snooze a task notification by rescheduling it [minutes] later.
  ///
  /// Returns the new scheduled notification time, or null if rescheduling failed.
  Future<DateTime?> snoozeNotification({
    required int id,
    required String title,
    required String body,
    required String? taskId,
    int minutes = 15,
    ReminderSound sound = ReminderSound.systemDefault,
  }) async {
    if (!_initialized) return null;

    final newTime = DateTime.now().add(Duration(minutes: minutes));
    final tzDate = tz.TZDateTime.from(newTime, tz.local);
    final channelId = _getChannelIdForSound(sound);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Task Reminders - ${sound.label}',
      channelDescription: 'Task reminder (snoozed)',
      importance: switch (sound) {
        ReminderSound.urgentBeep => Importance.max,
        ReminderSound.silent => Importance.low,
        _ => Importance.high,
      },
      priority: switch (sound) {
        ReminderSound.urgentBeep => Priority.max,
        ReminderSound.silent => Priority.low,
        _ => Priority.high,
      },
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActionIds.complete,
          '✓ Complete',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActionIds.snooze,
          '⏰ Snooze 15m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          NotificationActionIds.dismiss,
          '✕ Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Cancel existing notification first
    await _plugin.cancel(id);

    await _plugin.zonedSchedule(
      id,
      '$title (snoozed)',
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );

    log('Snoozed notification $id to $tzDate');
    return newTime;
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
