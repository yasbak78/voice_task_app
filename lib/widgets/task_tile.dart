import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/app_database.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    return ListTile(
      leading: IconButton(
        icon: Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? Colors.green : null,
        ),
        onPressed: onComplete,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: isDone ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.project != null)
            Text(
              task.project!,
              style:
                  TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
            ),
          if (task.dueDate != null)
            Text(
              _formatDueDate(task.dueDate!),
              style: TextStyle(
                color: _isOverdue(task) ? Colors.red : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: _priorityIcon(task.priority),
      onTap: onTap,
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff =
        date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isOverdue(Task task) =>
      task.status != TaskStatus.done &&
      task.dueDate != null &&
      DateTime.now().isAfter(task.dueDate!);

  Widget _priorityIcon(Priority priority) {
    final (icon, color) = switch (priority) {
      Priority.high => (Icons.flag, Colors.red),
      Priority.medium => (Icons.flag, Colors.orange),
      Priority.low => (Icons.flag, Colors.grey),
    };
    return Icon(icon, color: color, size: 20);
  }
}
