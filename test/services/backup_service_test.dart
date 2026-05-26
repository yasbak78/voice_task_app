import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/services/backup_service.dart';
import 'package:sqlite3/open.dart';

void _setupSqlite3() {
  if (Platform.isLinux) {
    const paths = [
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
    ];
    for (final path in paths) {
      if (File(path).existsSync()) {
        open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(path));
        break;
      }
    }
  }
}

void main() {
  _setupSqlite3();

  group('BackupService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    AppDatabase createTestDB() {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      return db;
    }

    test('exportToJson creates a valid JSON file', () async {
      final db = createTestDB();

      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'test-1',
        title: 'Test task',
        notes: Value('Some notes'),
        priority: Value(Priority.high),
        status: Value(TaskStatus.pending),
      ));

      final tasks = await db.taskDao.getAllTasks();
      expect(tasks.length, 1);

      final json = BackupService.serializeTasksToJson(tasks);
      expect(json, isA<List<Map<String, dynamic>>>());
      expect(json.length, 1);
      expect(json[0]['title'], 'Test task');
      expect(json[0]['priority'], 'high');
    });

    test('restoreFromJson with merge mode skips duplicates', () async {
      final db = createTestDB();

      // Insert an initial task
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'existing-1',
        title: 'Existing task',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
      ));

      // Create JSON with one existing and one new task
      final tasks = await db.taskDao.getAllTasks();
      expect(tasks.length, 1);

      final newTaskData = <String, dynamic>{
        'id': 'new-1',
        'title': 'New task',
        'priority': 'high',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'isCalendarEvent': false,
      };

      final existingTaskData = <String, dynamic>{
        'id': 'existing-1',
        'title': 'Updated existing task',
        'priority': 'low',
        'status': 'done',
        'createdAt': DateTime.now().toIso8601String(),
        'isCalendarEvent': false,
      };

      final allJson = [newTaskData, existingTaskData];

      final count = await BackupService.restoreFromJsonData(
        db,
        allJson,
        mode: RestoreMode.merge,
      );

      expect(count, 1); // Only new task inserted

      final tasksAfter = await db.taskDao.getAllTasks();
      expect(tasksAfter.length, 2);

      // The existing task should NOT be updated in merge mode
      final existingTask = await db.taskDao.getTaskById('existing-1');
      expect(existingTask!.title, 'Existing task');
    });

    test('restoreFromJson with replace mode clears then inserts', () async {
      final db = createTestDB();

      // Insert some initial tasks
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'old-1',
        title: 'Old task',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
      ));

      final jsonData = <Map<String, dynamic>>[
        {
          'id': 'restored-1',
          'title': 'Restored task',
          'priority': 'high',
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'isCalendarEvent': false,
        },
      ];

      final count = await BackupService.restoreFromJsonData(
        db,
        jsonData,
        mode: RestoreMode.replace,
      );

      expect(count, 1);

      final tasksAfter = await db.taskDao.getAllTasks();
      expect(tasksAfter.length, 1);
      expect(tasksAfter[0].title, 'Restored task');
    });

    test('clearAllData deletes all tasks', () async {
      final db = createTestDB();

      await db.taskDao.createTask(TasksCompanion.insert(
        id: 't1',
        title: 'Task 1',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
      ));
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 't2',
        title: 'Task 2',
        priority: Value(Priority.high),
        status: Value(TaskStatus.done),
      ));

      final before = await db.taskDao.getAllTasks();
      expect(before.length, 2);

      await BackupService.clearAllData(db);

      final after = await db.taskDao.getAllTasks();
      expect(after.length, 0);
    });

    test('serializeTasksToJson includes all fields', () async {
      final db = createTestDB();
      final now = DateTime.now();

      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'full-task',
        title: 'Full task',
        notes: Value('Detailed notes'),
        priority: Value(Priority.high),
        status: Value(TaskStatus.pending),
        dueDate: Value(now),
        project: Value('Work'),
        isCalendarEvent: Value(false),
      ));

      // Mark as completed to set completedAt
      await db.taskDao.markComplete('full-task');

      final tasks = await db.taskDao.getAllTasks();
      final json = BackupService.serializeTasksToJson(tasks);

      expect(json.length, 1);
      final taskJson = json[0];
      expect(taskJson['title'], 'Full task');
      expect(taskJson['notes'], 'Detailed notes');
      expect(taskJson['priority'], 'high');
      expect(taskJson['status'], 'done');
      expect(taskJson['project'], 'Work');
      expect(taskJson['dueDate'], isNotNull);
      expect(taskJson['completedAt'], isNotNull);
    });

    test('parseTaskFromJson handles data with nullable fields missing', () async {
      final taskMap = <String, dynamic>{
        'id': 'minimal',
        'title': 'Minimal task',
        'priority': 'medium',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'isCalendarEvent': false,
        // Nullable fields omitted: notes, dueDate, project, completedAt
      };

      final task = BackupService.parseTaskFromJson(taskMap);
      expect(task, isNotNull);
      expect(task!.id, 'minimal');
      expect(task.title, 'Minimal task');
      expect(task.notes, isNull);
      expect(task.dueDate, isNull);
      expect(task.project, isNull);
      expect(task.completedAt, isNull);
    });
  });
}
