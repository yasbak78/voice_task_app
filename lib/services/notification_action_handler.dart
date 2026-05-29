import 'dart:developer';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/notifications/notification_service.dart';
import 'package:voice_task_app/providers/task_providers.dart';
import 'package:voice_task_app/services/haptic_feedback_service.dart';
import 'package:voice_task_app/services/sound_preview_service.dart';

/// Handles notification tap and action button callbacks.
class NotificationActionHandler {
  final WidgetRef _ref;

  NotificationActionHandler(this._ref);

  /// Initialize notification service with tap + action handlers.
  void init(BuildContext context) {
    NotificationService.instance.init(
      onNotificationTapped: (taskId) {
        if (taskId != null && context.mounted) {
          final dao = _ref.read(taskDaoProvider);
          dao.getTaskById(taskId).then((task) {
            if (task != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _buildDetailScreen(task),
                ),
              );
            }
          });
        }
      },
      onAction: (actionId, taskId) {
        if (taskId == null) return;

        switch (actionId) {
          case NotificationActionIds.complete:
            _completeTask(taskId);
            break;
          case NotificationActionIds.snooze:
            _snoozeTask(taskId);
            break;
          case NotificationActionIds.dismiss:
            _dismissTask(taskId);
            break;
        }
      },
    );
  }

  Future<void> _completeTask(String taskId) async {
    try {
      // Haptic + audio feedback FIRST (instant UX)
      await HapticFeedbackService.trigger('success');
      SoundPreviewService.playChime(sound: 'completion_chime');

      final dao = _ref.read(taskDaoProvider);
      final task = await dao.getTaskById(taskId);
      if (task == null) {
        log('Task $taskId not found for completion');
        return;
      }
      await dao.updateTask(
        task.copyWith(
          completedAt: Value(DateTime.now()),
          status: TaskStatus.done,
        ),
      );
      // Cancel the notification for this task
      await NotificationService.instance.cancelNotification(taskId.hashCode);
      log('Task $taskId completed from notification action');
    } catch (e) {
      log('Failed to complete task $taskId: $e');
    }
  }

  Future<void> _snoozeTask(String taskId) async {
    try {
      // Haptic feedback for snooze action
      HapticFeedbackService.trigger('medium');

      final dao = _ref.read(taskDaoProvider);
      final task = await dao.getTaskById(taskId);
      if (task == null) {
        log('Task $taskId not found for snooze');
        return;
      }
      final sound = ReminderSound.fromId(task.reminderSound);
      final body = (task.notes != null && task.notes!.isNotEmpty)
          ? task.notes!
          : 'This task is due now';

      await NotificationService.instance.snoozeNotification(
        id: taskId.hashCode,
        title: 'Task due: ${task.title}',
        body: body,
        taskId: taskId,
        minutes: 15,
        sound: sound,
      );
      log('Task $taskId snoozed 15 minutes');
    } catch (e) {
      log('Failed to snooze task $taskId: $e');
    }
  }

  Future<void> _dismissTask(String taskId) async {
    try {
      // Haptic feedback for dismiss action
      HapticFeedbackService.trigger('medium');

      // Just cancel the notification — don't modify the task
      await NotificationService.instance.cancelNotification(taskId.hashCode);
      log('Task $taskId notification dismissed');
    } catch (e) {
      log('Failed to dismiss task $taskId: $e');
    }
  }

  // Navigate to task detail using the route defined in main.dart
  Widget _buildDetailScreen(Task task) {
    // Import the screen dynamically via the route
    return _TaskDetailWrapper(task: task);
  }
}

/// Simple wrapper that mirrors TaskDetailScreen without circular imports.
class _TaskDetailWrapper extends StatelessWidget {
  final Task task;
  const _TaskDetailWrapper({required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.notes != null) Text(task.notes!),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final dao = ProviderScope.containerOf(context).read(taskDaoProvider);
                    await dao.updateTask(
                      task.copyWith(
                        completedAt: Value(DateTime.now()),
                        status: TaskStatus.done,
                      ),
                    );
                    await NotificationService.instance.cancelNotification(task.id.hashCode);
                    // Phase 3: Haptic + chime on completion
                    HapticFeedbackService.trigger('heavy');
                    SoundPreviewService.playChime(sound: 'completion_chime');
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Complete'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
