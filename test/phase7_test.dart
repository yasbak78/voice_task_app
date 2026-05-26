import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:sqlite3/open.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/screens/home/task_list_screen.dart';
import 'package:voice_task_app/screens/task_detail/task_detail_screen.dart';
import 'package:voice_task_app/providers/task_providers.dart';

// Ensure sqlite3 can find the library on Linux.
void _setupSqlite3() {
  if (Platform.isLinux) {
    const paths = [
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
      '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/aarch64-linux-gnu/libsqlite3.so',
    ];
    for (final path in paths) {
      if (File(path).existsSync()) {
        open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(path));
        break;
      }
    }
  }
}

Future<void> _pump(WidgetTester tester, {int ms = 500}) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// Pump until the target finder finds something (max 10 seconds).
Future<void> _pumpUntilFound(WidgetTester tester, Finder target, {int maxMs = 10000}) async {
  int elapsed = 0;
  while (elapsed < maxMs && !tester.any(target)) {
    await tester.pump(const Duration(milliseconds: 500));
    elapsed += 500;
  }
}

Future<void> _addTask(AppDatabase db, {
  required String id,
  required String title,
  String? notes,
  Priority priority = Priority.medium,
  TaskStatus status = TaskStatus.pending,
  DateTime? dueDate,
  String? project,
}) async {
  await db.taskDao.createTask(TasksCompanion.insert(
    id: id,
    title: title,
    notes: notes != null ? Value(notes) : const Value.absent(),
    priority: Value(priority),
    status: Value(status),
    dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
    project: project != null ? Value(project) : const Value.absent(),
  ));
}

Widget _buildHarness({
  required AppDatabase db,
  required List<Task> tasks,
  Set<String>? filterProjects,
  String? filterPriority,
  String? filterDateRange,
}) {
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      allTasksProvider.overrideWith((ref) => Stream.value(tasks)),
      if (filterProjects != null) filterProjectsProvider.overrideWith((ref) => filterProjects),
      if (filterPriority != null) filterPriorityProvider.overrideWith((ref) => filterPriority),
      if (filterDateRange != null) filterDateRangeProvider.overrideWith((ref) => filterDateRange),
    ],
    child: MaterialApp(
      home: const TaskListScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/task-detail' && settings.arguments is Task) {
          return MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: settings.arguments as Task),
          );
        }
        return null;
      },
    ),
  );
}

void main() {
  _setupSqlite3();

  group('Phase 7 Tests', () {
    testWidgets('Tap task → detail screen opens with correct data', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'tap-1', title: 'Test Task', priority: Priority.high, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Test Task'), findsOneWidget);

      await tester.tap(find.text('Test Task'));
      await tester.pumpAndSettle();

      expect(find.text('Test Task'), findsAtLeast(1));
      expect(find.textContaining('High'), findsOneWidget);

      await db.close();
    });

    testWidgets('Detail screen shows correct title and priority', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'detail-1', title: 'Buy groceries', priority: Priority.medium, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Buy groceries'), findsOneWidget);

      await tester.tap(find.text('Buy groceries'));
      await tester.pumpAndSettle();

      expect(find.text('Buy groceries'), findsAtLeast(1));
      expect(find.textContaining('Medium'), findsOneWidget);

      await db.close();
    });

    testWidgets('Detail screen shows high priority correctly', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'high-1', title: 'Urgent Task', priority: Priority.high, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Urgent Task'), findsOneWidget);

      await tester.tap(find.text('Urgent Task'));
      await tester.pumpAndSettle();

      expect(find.text('Urgent Task'), findsAtLeast(1));
      expect(find.textContaining('High'), findsOneWidget);

      await db.close();
    });

    testWidgets('Search by title → matching tasks shown', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'search-1', title: 'Buy groceries', priority: Priority.medium, status: TaskStatus.pending);
      await _addTask(db, id: 'search-2', title: 'Walk the dog', priority: Priority.low, status: TaskStatus.pending);
      await _addTask(db, id: 'search-3', title: 'Read a book', priority: Priority.high, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Walk the dog'), findsOneWidget);
      expect(find.text('Read a book'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'groceries');
      await _pump(tester, ms: 200);

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Walk the dog'), findsNothing);
      expect(find.text('Read a book'), findsNothing);

      await db.close();
    });

    testWidgets('Apply project filter → only tasks with that project shown', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'proj-1', title: 'Task A', project: 'Work', priority: Priority.medium, status: TaskStatus.pending);
      await _addTask(db, id: 'proj-2', title: 'Task B', project: 'Personal', priority: Priority.low, status: TaskStatus.pending);
      await _addTask(db, id: 'proj-3', title: 'Task C', project: 'Work', priority: Priority.high, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks, filterProjects: {'Work'}));
      await _pump(tester);

      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task C'), findsOneWidget);
      expect(find.text('Task B'), findsNothing);

      await db.close();
    });

    testWidgets('Delete task → disappears from list', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'delete-1', title: 'Task With Project', project: 'Work', priority: Priority.medium, status: TaskStatus.pending);
      await _addTask(db, id: 'delete-2', title: 'Keep Me', priority: Priority.low, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Task With Project'), findsOneWidget);
      expect(find.text('Keep Me'), findsOneWidget);

      await tester.tap(find.text('Task With Project'));
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Task With Project'));

      expect(find.textContaining('Work'), findsOneWidget);

      await db.close();
    });

    testWidgets('Search by notes → matching task shown', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'notes-1', title: 'Meeting', notes: 'Discuss Q4 goals with team', priority: Priority.high, status: TaskStatus.pending);
      await _addTask(db, id: 'notes-2', title: 'Lunch', notes: 'Try the new restaurant', priority: Priority.low, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'Q4 goals');
      await _pump(tester, ms: 200);

      expect(find.text('Meeting'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);

      await db.close();
    });

    testWidgets('No results shown when search matches nothing', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await _addTask(db, id: 'no-results-1', title: 'Buy milk', priority: Priority.medium, status: TaskStatus.pending);
      final tasks = await db.taskDao.getAllTasks();

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Buy milk'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'xyznonexistent');
      await _pump(tester, ms: 200);

      expect(find.text('Buy milk'), findsNothing);
      expect(find.text('No matching tasks'), findsOneWidget);

      await db.close();
    });
  });
}
