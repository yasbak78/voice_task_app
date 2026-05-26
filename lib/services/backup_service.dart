import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/database/app_database.dart';

/// Service for backing up and restoring tasks to/from JSON files.
class BackupService {
  /// Serialize a list of tasks to JSON (exportable map list).
  static List<Map<String, dynamic>> serializeTasksToJson(List<Task> tasks) {
    return tasks.map((t) {
      final json = t.toJson();
      json['createdAt'] = t.createdAt.toIso8601String();
      json['dueDate'] = t.dueDate?.toIso8601String();
      json['completedAt'] = t.completedAt?.toIso8601String();
      return json;
    }).toList();
  }

  /// Parse a single task from a JSON map.
  static Task? parseTaskFromJson(Map<String, dynamic> json) {
    try {
      // Provide defaults for new fields that may be missing in old backups
      json.putIfAbsent('hasReminder', () => false);
      json.putIfAbsent('reminderTime', () => null);
      return Task.fromJson(json);
    } catch (e) {
      debugPrint('Failed to parse task from JSON: $e');
      return null;
    }
  }

  /// Restore tasks from already-parsed JSON data (useful for testing).
  static Future<int> restoreFromJsonData(
    AppDatabase db,
    List<Map<String, dynamic>> jsonData, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    if (mode == RestoreMode.replace) {
      final existing = await db.taskDao.getAllTasks();
      for (final t in existing) {
        await db.taskDao.deleteTask(t.id);
      }
    }

    int restored = 0;
    final existingIds = mode == RestoreMode.merge
        ? (await db.taskDao.getAllTasks()).map((t) => t.id).toSet()
        : <String>{};

    for (final json in jsonData) {
      final id = json['id'] as String?;
      if (id == null) continue;

      if (mode == RestoreMode.merge && existingIds.contains(id)) {
        continue;
      }

      final task = parseTaskFromJson(json);
      if (task == null) continue;

      try {
        await db.taskDao.createTask(TasksCompanion.insert(
          id: task.id,
          title: task.title,
          notes: task.notes != null ? Value(task.notes!) : const Value.absent(),
          priority: Value(task.priority),
          status: Value(task.status),
          dueDate: task.dueDate != null
              ? Value(task.dueDate!)
              : const Value.absent(),
          project: task.project != null
              ? Value(task.project!)
              : const Value.absent(),
          createdAt: Value(task.createdAt),
          completedAt: task.completedAt != null
              ? Value(task.completedAt!)
              : const Value.absent(),
          hasReminder: Value(task.hasReminder),
          reminderTime: task.reminderTime != null
              ? Value(task.reminderTime!)
              : const Value.absent(),
          isCalendarEvent: Value(task.isCalendarEvent),
        ));
        restored++;
      } catch (e) {
        debugPrint('Failed to restore task $id: $e');
      }
    }

    return restored;
  }
  /// Export all tasks from the database to a JSON file.
  ///
  /// Returns the path of the created backup file.
  static Future<String> exportToJson(AppDatabase db) async {
    final tasks = await db.taskDao.getAllTasks();

    final jsonData = tasks.map((t) {
      final json = t.toJson();
      // Ensure consistent date formatting
      json['createdAt'] = t.createdAt.toIso8601String();
      json['dueDate'] = t.dueDate?.toIso8601String();
      json['completedAt'] = t.completedAt?.toIso8601String();
      return json;
    }).toList();

    final encoded = const JsonEncoder.withIndent('  ').convert(jsonData);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = p.join(dir.path, 'voice_tasks_backup_$timestamp.json');
    final file = File(filePath);
    await file.writeAsString(encoded);

    debugPrint('Backup exported to: $filePath');
    return filePath;
  }

  /// Restore tasks from a JSON backup file.
  ///
  /// [mode] controls how existing tasks are handled:
  /// - `RestoreMode.merge`: Skips tasks that already exist (by ID).
  /// - `RestoreMode.replace`: Deletes all existing tasks first, then inserts.
  ///
  /// Returns the number of tasks restored.
  static Future<int> restoreFromJson(
    AppDatabase db,
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Backup file not found', filePath);
    }

    final content = await file.readAsString();
    final List<dynamic> rawList = jsonDecode(content) as List<dynamic>;

    if (mode == RestoreMode.replace) {
      final existing = await db.taskDao.getAllTasks();
      for (final t in existing) {
        await db.taskDao.deleteTask(t.id);
      }
    }

    int restored = 0;
    final existingIds = mode == RestoreMode.merge
        ? (await db.taskDao.getAllTasks()).map((t) => t.id).toSet()
        : <String>{};

    for (final raw in rawList) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null) continue;

      if (mode == RestoreMode.merge && existingIds.contains(id)) {
        debugPrint('Skipping existing task: $id');
        continue;
      }

      final task = Task.fromJson(json);
      try {
        await db.taskDao.createTask(TasksCompanion.insert(
          id: task.id,
          title: task.title,
          notes: task.notes != null ? Value(task.notes!) : const Value.absent(),
          priority: Value(task.priority),
          status: Value(task.status),
          dueDate:
              task.dueDate != null ? Value(task.dueDate!) : const Value.absent(),
          project: task.project != null
              ? Value(task.project!)
              : const Value.absent(),
          createdAt: Value(task.createdAt),
          completedAt: task.completedAt != null
              ? Value(task.completedAt!)
              : const Value.absent(),
          hasReminder: Value(task.hasReminder),
          reminderTime: task.reminderTime != null
              ? Value(task.reminderTime!)
              : const Value.absent(),
          isCalendarEvent: Value(task.isCalendarEvent),
        ));
        restored++;
      } catch (e) {
        debugPrint('Failed to restore task $id: $e');
      }
    }

    debugPrint('Restored $restored tasks from $filePath');
    return restored;
  }

  /// Delete ALL tasks from the database.
  ///
  /// Returns the number of deleted tasks.
  static Future<int> clearAllData(AppDatabase db) async {
    final tasks = await db.taskDao.getAllTasks();
    for (final t in tasks) {
      await db.taskDao.deleteTask(t.id);
    }
    debugPrint('Cleared ${tasks.length} tasks');
    return tasks.length;
  }
}

/// Restore mode for backup import.
enum RestoreMode {
  /// Skip tasks that already exist (match by ID).
  merge,

  /// Delete all existing tasks, then insert from backup.
  replace,
}
