import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../core/notifications/notification_service.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final taskDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).tasksDao;
});

final calendarDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).calendarDao;
});

final settingsDaoProvider = Provider((ref) {
  return ref.watch(dbProvider).settingsDao;
});

final allTasksProvider = StreamProvider((ref) {
  return ref.watch(taskDaoProvider).watchAllTasks();
});

final todayTasksProvider = StreamProvider((ref) {
  return ref.watch(taskDaoProvider).watchTasksDueToday();
});

final taskStatsProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final tasks = ref.watch(allTasksProvider);
  return tasks.when(
    data: (list) => AsyncValue.data({
      'total': list.length,
      'pending':
          list.where((t) => t.status == TaskStatus.pending).length,
      'done': list.where((t) => t.status == TaskStatus.done).length,
      'overdue': list
          .where((t) =>
              t.status != TaskStatus.done &&
              t.dueDate != null &&
              DateTime.now().isAfter(t.dueDate!))
          .length,
    }),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
/// Task notification manager - schedules/cancels notifications based on task state.
class TaskNotificationManager {
  /// Schedule or cancel a notification when a task is created/updated.
  static Future<void> syncNotification(Task task, AppDatabase db) async {
    try {
      final enabled = await db.settingsDao.getValue('notifications_enabled');
      final isEnabled = enabled != 'false';

      if (!isEnabled || task.dueDate == null || !task.hasReminder) {
        await NotificationService.instance.cancelNotification(task.id.hashCode);
        return;
      }

      DateTime notifyTime = task.dueDate!;
      if (task.reminderTime != null) {
        final parts = task.reminderTime!.split(':');
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        notifyTime = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          hours,
          minutes,
        );
      }

      if (notifyTime.isBefore(DateTime.now())) {
        await NotificationService.instance.cancelNotification(task.id.hashCode);
        return;
      }

      final body = (task.notes != null && task.notes!.isNotEmpty)
          ? task.notes!
          : 'This task is due now';

      await NotificationService.instance.scheduleTaskNotification(
        id: task.id.hashCode,
        title: 'Task due: ${task.title}',
        body: body,
        scheduledDate: notifyTime,
        taskId: task.id,
      );
    } catch (e) {
      debugPrint('Failed to sync notification for task ${task.id}: $e');
    }
  }

  static Future<void> cancelNotificationForTask(String taskId) async {
    try {
      await NotificationService.instance.cancelNotification(taskId.hashCode);
    } catch (e) {
      debugPrint('Failed to cancel notification for task $taskId: $e');
    }
  }
}
