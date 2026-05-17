import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../models/task_model.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Priority', task.priority.displayName),
            if (task.dueDate != null)
              _infoRow('Due',
                  task.dueDate.toString().split(' ')[0]),
            if (task.project != null)
              _infoRow('Project', task.project!),
            _infoRow('Status', task.status.displayName),
            _infoRow('Created',
                task.createdAt.toString().split(' ')[0]),
            if (task.notes != null) ...[
              const SizedBox(height: 16),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(task.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
