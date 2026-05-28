import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

extension PriorityExt on Priority {
  String get displayName => switch (this) {
        Priority.high => 'High',
        Priority.medium => 'Medium',
        Priority.low => 'Low',
      };

  String get colorHex => switch (this) {
        Priority.high => '#EF4444',
        Priority.medium => '#F59E0B',
        Priority.low => '#22C55E',
      };
}

extension TaskStatusExt on TaskStatus {
  String get displayName => switch (this) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.done => 'Done',
        TaskStatus.archived => 'Archived',
      };
}

extension TaskHelper on Task {
  bool get isOverdue =>
      dueDate != null && status != TaskStatus.done && DateTime.now().isAfter(dueDate!);

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isAfter(today) &&
        dueDate!.isBefore(today.add(const Duration(days: 1)));
  }

  bool get isDueThisWeek {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    return dueDate!.isAfter(now) && dueDate!.isBefore(weekEnd);
  }
}

Task createTask({
  String? id,
  required String title,
  String? notes,
  DateTime? dueDate,
  Priority priority = Priority.medium,
  String? project,
  TaskStatus status = TaskStatus.pending,
  DateTime? createdAt,
  DateTime? completedAt,
  bool hasReminder = false,
  String? reminderTime,
  String? reminderSound,
}) {
  return Task(
    id: id ?? const Uuid().v4(),
    title: title,
    notes: notes,
    dueDate: dueDate,
    priority: priority,
    project: project,
    status: status,
    createdAt: createdAt ?? DateTime.now(),
    completedAt: completedAt,
    hasReminder: hasReminder,
    reminderTime: reminderTime,
    reminderSound: reminderSound ?? 'system_default',
    isCalendarEvent: false,
  );
}
