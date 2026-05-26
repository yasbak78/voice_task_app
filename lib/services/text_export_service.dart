import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/database/app_database.dart';

/// Service for exporting tasks as plain text files.
class TextExportService {
  /// Export tasks to a plain text file and share it.
  ///
  /// Returns the path of the created text file.
  static Future<String> exportAndShare(AppDatabase db) async {
    final tasks = await db.taskDao.getAllTasks();
    final textContent = _tasksToText(tasks);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(dir.path, 'voice_tasks_$timestamp.txt');
    final file = File(filePath);
    await file.writeAsString(textContent);

    debugPrint('Text export saved to: $filePath');

    // Share the file using share_plus
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Voice Tasks Export',
      text: '${tasks.length} tasks exported',
    );

    return filePath;
  }

  /// Convert a list of tasks to a readable plain text format.
  static String _tasksToText(List<Task> tasks) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    buffer.writeln('Voice Tasks Export');
    buffer.writeln('Generated: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('Total tasks: ${tasks.length}');
    buffer.writeln('=' * 50);
    buffer.writeln('');

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      buffer.writeln('Task #${i + 1}: ${task.title}');
      buffer.writeln('  Status:   ${task.status.name}');
      buffer.writeln('  Priority: ${task.priority.name}');

      if (task.dueDate != null) {
        buffer.writeln('  Due:      ${dateFormat.format(task.dueDate!)}');
      }
      if (task.project != null && task.project!.isNotEmpty) {
        buffer.writeln('  Project:  ${task.project}');
      }
      if (task.notes != null && task.notes!.isNotEmpty) {
        buffer.writeln('  Notes:    ${task.notes}');
      }
      buffer.writeln('  Created:  ${dateFormat.format(task.createdAt)}');

      if (task.completedAt != null) {
        buffer.writeln('  Completed: ${dateFormat.format(task.completedAt!)}');
      }

      if (i < tasks.length - 1) {
        buffer.writeln('-' * 50);
      }
    }

    return buffer.toString();
  }
}
