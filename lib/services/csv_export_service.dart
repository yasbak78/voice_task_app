import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/database/app_database.dart';

/// Service for exporting tasks as CSV files.
class CsvExportService {
  /// CSV column headers.
  static const headers = ['title', 'notes', 'due_date', 'priority', 'project', 'status', 'tags'];

  /// Export tasks to a CSV file and share it.
  ///
  /// Returns the path of the created CSV file.
  static Future<String> exportAndShare(AppDatabase db) async {
    final tasks = await db.taskDao.getAllTasks();
    final csvContent = _tasksToCsv(tasks);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(dir.path, 'voice_tasks_$timestamp.csv');
    final file = File(filePath);
    await file.writeAsString(csvContent);

    debugPrint('CSV exported to: $filePath');

    // Share the file using share_plus
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Voice Tasks Export',
      text: '${tasks.length} tasks exported',
    );

    return filePath;
  }

  /// Convert a list of tasks to CSV format.
  static String _tasksToCsv(List<Task> tasks) {
    final buffer = StringBuffer();

    // Write header row
    buffer.writeln(headers.join(','));

    // Write data rows
    for (final task in tasks) {
      final row = [
        _escapeCsv(task.title),
        _escapeCsv(task.notes ?? ''),
        task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!) : '',
        task.priority.name,
        _escapeCsv(task.project ?? ''),
        task.status.name,
        '', // tags placeholder (not stored in DB yet)
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Escape a CSV field value.
  ///
  /// Wraps in quotes if the value contains commas, quotes, or newlines.
  static String _escapeCsv(String value) {
    if (value.isEmpty) return '';
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
