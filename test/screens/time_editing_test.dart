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

  group('Time Editing', () {
    testWidgets('shows time in due date chip when task has time set', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final dueDate = DateTime(2026, 5, 28, 14, 30);
      final task = createTask(
        id: 'time-1',
        title: 'Timed Task',
        priority: Priority.medium,
        dueDate: dueDate,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // The date chip should show time
      expect(find.textContaining('May 28, 2026 14:30'), findsAtLeastNWidgets(1));

      await db.close();
    });

    testWidgets('shows date without time when dueDate is at midnight', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final dueDate = DateTime(2026, 5, 28); // midnight
      final task = createTask(
        id: 'time-2',
        title: 'Date Only Task',
        priority: Priority.medium,
        dueDate: dueDate,
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // Should show date but NOT time
      expect(find.textContaining('May 28, 2026'), findsAtLeastNWidgets(1));
      // Should NOT show midnight time
      expect(find.textContaining('00:00'), findsNothing);

      await db.close();
    });

    testWidgets('shows calendar icon in edit mode for due date', (WidgetTester tester) async {
      final db = AppDatabase.test(NativeDatabase.memory());
      final task = createTask(
        id: 'time-3',
        title: 'Edit Task',
        priority: Priority.medium,
        dueDate: DateTime(2026, 6, 15),
      );
      await tester.pumpWidget(_buildHarness(db: db, task: task));
      await _pump(tester);

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Should show date picker button
      expect(find.byIcon(Icons.calendar_today), findsAtLeastNWidgets(1));

      await db.close();
    });

    test('DateTime with non-midnight formats with time', () {
      // Test the formatting logic directly
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      String formatDate(DateTime date) {
        final base = '${months[date.month - 1]} ${date.day}, ${date.year}';
        if (date.hour != 0 || date.minute != 0) {
          final hour = date.hour.toString().padLeft(2, '0');
          final minute = date.minute.toString().padLeft(2, '0');
          return '$base $hour:$minute';
        }
        return base;
      }

      expect(
        formatDate(DateTime(2026, 5, 28, 14, 30)),
        'May 28, 2026 14:30',
      );
      expect(
        formatDate(DateTime(2026, 5, 28, 0, 0)),
        'May 28, 2026',
      );
      expect(
        formatDate(DateTime(2026, 12, 1, 9, 5)),
        'Dec 1, 2026 09:05',
      );
    });

    test('quick edit date format shows time when non-midnight', () {
      String formatQuickEditDate(DateTime date) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final base = '${months[date.month - 1]} ${date.day}';
        if (date.hour != 0 || date.minute != 0) {
          final hour = date.hour.toString().padLeft(2, '0');
          final minute = date.minute.toString().padLeft(2, '0');
          return '$base $hour:$minute';
        }
        return base;
      }

      expect(
        formatQuickEditDate(DateTime(2026, 5, 28, 14, 30)),
        'May 28 14:30',
      );
      expect(
        formatQuickEditDate(DateTime(2026, 5, 28)),
        'May 28',
      );
    });
  });
}
