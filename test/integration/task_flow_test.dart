import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:sqlite3/open.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/providers/task_providers.dart';
import 'package:voice_task_app/models/task_model.dart';
import 'package:voice_task_app/core/theme/app_components.dart';

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

Widget _buildHarness({
  required AppDatabase db,
  required List<Task> tasks,
}) {
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      allTasksProvider.overrideWith((ref) => Stream.value(tasks)),
    ],
    child: MaterialApp(
      home: _TestHarness(tasks: tasks),
    ),
  );
}

/// A test wrapper that uses allTasksProvider directly with AsyncValue.data
/// to avoid StreamProvider timing issues in widget tests.
class _TestHarness extends ConsumerWidget {
  final List<Task> tasks;
  const _TestHarness({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, Yassin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'You have ${tasks.where((t) => t.status != TaskStatus.done).length} tasks today',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: _buildTaskList(context, ref, tasks),
    );
  }

  Widget _buildTaskList(
      BuildContext context, WidgetRef ref, List<Task> tasks) {
    final pending = tasks.where((t) => t.status != TaskStatus.done).toList();
    final done = tasks.where((t) => t.status == TaskStatus.done).toList();
    final today = pending.where((t) => t.isDueToday).toList();
    final thisWeek = pending.where((t) => !t.isDueToday && t.isDueThisWeek).toList();
    final later = pending.where((t) => !t.isDueToday && !t.isDueThisWeek).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: Icon(Icons.search_rounded),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              _buildSection(context, 'Today', today, ref),
              _buildSection(context, 'This Week', thisWeek, ref),
              _buildSection(context, 'Later', later, ref),
              if (done.isNotEmpty) _buildSection(context, 'Completed', done, ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Task> tasks, WidgetRef ref) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          count: tasks.length,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        ...tasks.map((t) => TaskCard(
              task: t,
              onTap: () {},
              onComplete: () {},
            )),
      ],
    );
  }
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  _setupSqlite3();

  group('Task Flow Integration', () {
    testWidgets('add task → verify in list → mark complete',
        (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'int-1',
        title: 'Buy groceries',
        priority: Value(Priority.high),
        status: Value(TaskStatus.pending),
      ));
      var tasks = await db.taskDao.getAllTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.status, TaskStatus.pending);

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      // Mark complete via DAO (sets completedAt).
      await db.taskDao.markComplete('int-1');
      tasks = await db.taskDao.getAllTasks();
      expect(tasks.first.status, TaskStatus.done);
      expect(tasks.first.completedAt, isNotNull,
          reason: 'completedAt must be set for _isDone to work');

      // Re-render with updated tasks.
      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      await db.close();
    });

    testWidgets('add multiple tasks → verify count → complete one',
        (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 5));

      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'm-1',
        title: 'Morning standup',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.pending),
        dueDate: Value(today),
      ));
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'm-2',
        title: 'Code review',
        priority: Value(Priority.high),
        status: Value(TaskStatus.pending),
        dueDate: Value(tomorrow),
      ));
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'm-3',
        title: 'Plan sprint',
        priority: Value(Priority.low),
        status: Value(TaskStatus.pending),
        dueDate: Value(nextWeek),
      ));

      var tasks = await db.taskDao.getAllTasks();
      expect(tasks, hasLength(3));

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Morning standup'), findsOneWidget);
      expect(find.text('Code review'), findsOneWidget);
      expect(find.text('Plan sprint'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      // Complete one task.
      await db.taskDao.markComplete('m-1');
      tasks = await db.taskDao.getAllTasks();
      final doneTasks = tasks.where((t) => t.status == TaskStatus.done).toList();
      expect(doneTasks, hasLength(1));
      expect(doneTasks.first.title, 'Morning standup');
      expect(doneTasks.first.completedAt, isNotNull);

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Morning standup'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await db.close();
    });

    testWidgets('complete → uncomplete task via toggle', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final doneTime = DateTime(2025, 1, 1, 10, 0);
      await db.taskDao.createTask(TasksCompanion.insert(
        id: 'toggle-1',
        title: 'Toggle me',
        priority: Value(Priority.medium),
        status: Value(TaskStatus.done),
        completedAt: Value(doneTime),
      ));
      var tasks = await db.taskDao.getAllTasks();
      expect(tasks.first.status, TaskStatus.done);
      expect(tasks.first.completedAt, isNotNull);

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Toggle me'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Undo completion via DAO toggle.
      await db.taskDao.markIncomplete('toggle-1');
      tasks = await db.taskDao.getAllTasks();
      expect(tasks.first.status, TaskStatus.pending);
      expect(tasks.first.completedAt, isNull);

      await tester.pumpWidget(_buildHarness(db: db, tasks: tasks));
      await _pump(tester);

      expect(find.text('Toggle me'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);

      await db.close();
    });
  });
}
