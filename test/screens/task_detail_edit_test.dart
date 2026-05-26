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
import 'package:voice_task_app/screens/task_detail/task_detail_screen.dart';

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
  required Task task,
}) {
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      taskDaoProvider.overrideWithValue(db.taskDao),
      allTasksProvider.overrideWith((ref) => Stream.value([task])),
    ],
    child: MaterialApp(
      home: TaskDetailScreen(task: task),
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

  group('TaskDetailScreen Edit Mode', () {
    testWidgets('shows edit button in app bar', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'edit-1',
        title: 'Test Task',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.text('Test Task'), findsAtLeastNWidgets(1));

      await db.close();
    });

    testWidgets('entering edit mode shows editable fields', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'edit-2',
        title: 'Original Title',
        notes: 'Some notes',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Should show editable title field
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await db.close();
    });

    testWidgets('cancel edit restores original view', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'edit-3',
        title: 'Original Title',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should be back to original view
      expect(find.text('Original Title'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);

      await db.close();
    });

    testWidgets('empty title shows validation error on save', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'edit-4',
        title: 'Valid Title',
        priority: Priority.medium,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // Enter edit mode and clear title
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      // Try to save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(find.text('Title cannot be empty'), findsOneWidget);
      // Should still be in edit mode
      expect(find.byIcon(Icons.save), findsOneWidget);

      await db.close();
    });
  });
}
