import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:matcher/matcher.dart' show isNotNull, isNull;

AppDatabase createTestDB() {
  final db = AppDatabase.test(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  group('TaskDao', () {
    test('createTask inserts a task', () async {
      final db = createTestDB();
      final id = 'test-1';
      final count = await db.taskDao.createTask(
        TasksCompanion.insert(
          id: id,
          title: 'Test task',
          priority: Value(Priority.medium),
          status: Value(TaskStatus.pending),
        ),
      );
      expect(count, 1);
      final task = await db.taskDao.getTaskById(id);
      expect(task, isNotNull);
      expect(task!.title, 'Test task');
    });

    test('getAllTasks returns all tasks', () async {
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
        status: Value(TaskStatus.pending),
      ));
      final tasks = await db.taskDao.getAllTasks();
      expect(tasks.length, 2);
    });

    test('markComplete updates status and sets completedAt', () async {
      final db = createTestDB();
      final id = 't3';
      await db.taskDao.createTask(TasksCompanion.insert(
        id: id,
        title: 'Complete me',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
      ));
      await db.taskDao.markComplete(id);
      final task = await db.taskDao.getTaskById(id);
      expect(task!.status, TaskStatus.done);
      expect(task.completedAt, isNotNull);
    });

    test('deleteTask removes the task', () async {
      final db = createTestDB();
      final id = 't4';
      await db.taskDao.createTask(TasksCompanion.insert(
        id: id,
        title: 'Delete me',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
      ));
      await db.taskDao.deleteTask(id);
      final task = await db.taskDao.getTaskById(id);
      expect(task, isNull);
    });

    test('getTasksDueToday returns only today tasks', () async {
      final db = createTestDB();
      final today = DateTime.now();
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 't5',
        title: 'Today task',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
        dueDate: Value(today),
      ));
      final tomorrow = today.add(const Duration(days: 1));
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 't6',
        title: 'Tomorrow task',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
        dueDate: Value(tomorrow),
      ));
      final dueToday = await db.taskDao.getTasksDueToday();
      expect(dueToday.length, 1);
      expect(dueToday[0].title, 'Today task');
    });
  });
}
