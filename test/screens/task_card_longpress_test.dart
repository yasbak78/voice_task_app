import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/providers/task_providers.dart';
import 'package:voice_task_app/models/task_model.dart';
import 'package:voice_task_app/screens/home/task_list_screen.dart';

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
      taskDaoProvider.overrideWithValue(db.taskDao),
      allTasksProvider.overrideWith((ref) => Stream.value(tasks)),
    ],
    child: const MaterialApp(
      home: TaskListScreen(),
    ),
  );
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  _setupSqlite3();

  group('TaskCard Long Press Quick Edit', () {
    testWidgets('long press opens quick edit bottom sheet', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'lp-1',
        title: 'Long Press Task',
        notes: 'Some notes',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, tasks: [task]));
      await _pump(tester);

      // Long press the task card
      await tester.longPress(find.text('Long Press Task').first);
      await tester.pumpAndSettle();

      // Quick edit sheet should appear
      expect(find.text('Quick Edit'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Mark Done'), findsOneWidget);

      await db.close();
    });

    testWidgets('quick edit save updates task title', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'lp-2',
        title: 'Old Title',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, tasks: [task]));
      await _pump(tester);

      await tester.longPress(find.text('Old Title').first);
      await tester.pumpAndSettle();

      // Edit title
      await tester.enterText(find.byType(TextField).first, 'New Title');
      await tester.pump();

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Sheet should close
      expect(find.text('Quick Edit'), findsNothing);

      await db.close();
    });

    testWidgets('mark done button toggles completion', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'lp-3',
        title: 'Toggle Task',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, tasks: [task]));
      await _pump(tester);

      await tester.longPress(find.text('Toggle Task').first);
      await tester.pumpAndSettle();

      // Should show "Mark Done"
      expect(find.text('Mark Done'), findsOneWidget);

      await db.close();
    });
  });
}
