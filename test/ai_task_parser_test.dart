import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/services/ai_task_parser.dart';
import 'package:voice_task_app/core/database/app_database.dart';

void main() {
  group('AIParsedTask', () {
    test('fromJson parses valid JSON', () {
      final json = {
        'title': 'Buy milk',
        'priority': 'high',
        'dueDate': '2025-01-15',
        'dueTime': '09:00',
        'hasReminder': true,
        'reminderOffsetMinutes': 15,
        'project': 'Home',
        'notes': 'Get whole milk',
      };

      final task = AIParsedTask.fromJson(json);

      expect(task.title, 'Buy milk');
      expect(task.priority, 'high');
      expect(task.dueDate, '2025-01-15');
      expect(task.dueTime, '09:00');
      expect(task.hasReminder, true);
      expect(task.reminderOffsetMinutes, 15);
      expect(task.project, 'Home');
      expect(task.notes, 'Get whole milk');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'title': 'Simple task',
        'priority': 'medium',
        'hasReminder': false,
      };

      final task = AIParsedTask.fromJson(json);

      expect(task.title, 'Simple task');
      expect(task.priority, 'medium');
      expect(task.hasReminder, false);
      expect(task.dueDate, isNull);
      expect(task.dueTime, isNull);
      expect(task.project, isNull);
      expect(task.notes, isNull);
    });

    test('listFromJson parses array', () {
      final jsonArray = [
        {'title': 'Task A', 'priority': 'high', 'hasReminder': false},
        {'title': 'Task B', 'priority': 'low', 'hasReminder': true},
      ];

      final tasks = AIParsedTask.listFromJson(jsonArray);

      expect(tasks.length, 2);
      expect(tasks[0].title, 'Task A');
      expect(tasks[1].title, 'Task B');
    });

    test('listFromJson handles empty array', () {
      final tasks = AIParsedTask.listFromJson([]);
      expect(tasks, isEmpty);
    });

    test('toParsedTask converts priority correctly', () {
      expect(
        AIParsedTask.fromJson({
              'title': 'T',
              'priority': 'high',
              'hasReminder': false,
            })
            .toParsedTask()
            .priority,
        Priority.high,
      );
      expect(
        AIParsedTask.fromJson({
              'title': 'T',
              'priority': 'low',
              'hasReminder': false,
            })
            .toParsedTask()
            .priority,
        Priority.low,
      );
      expect(
        AIParsedTask.fromJson({
              'title': 'T',
              'priority': 'medium',
              'hasReminder': false,
            })
            .toParsedTask()
            .priority,
        Priority.medium,
      );
      // Default to medium for unknown
      expect(
        AIParsedTask.fromJson({
              'title': 'T',
              'priority': null,
              'hasReminder': false,
            })
            .toParsedTask()
            .priority,
        Priority.medium,
      );
    });

    test('toParsedTask parses dueDate correctly', () {
      final parsed = AIParsedTask.fromJson({
        'title': 'T',
        'priority': 'medium',
        'hasReminder': false,
        'dueDate': '2025-06-15',
      }).toParsedTask();

      expect(parsed.dueDate, isNotNull);
      expect(parsed.dueDate!.year, 2025);
      expect(parsed.dueDate!.month, 6);
      expect(parsed.dueDate!.day, 15);
    });

    test('toParsedTask parses dueTime correctly', () {
      final parsed = AIParsedTask.fromJson({
        'title': 'T',
        'priority': 'medium',
        'hasReminder': false,
        'dueTime': '14:30',
      }).toParsedTask();

      expect(parsed.dueTime, isNotNull);
      expect(parsed.dueTime!.hour, 14);
      expect(parsed.dueTime!.minute, 30);
    });

    test('toParsedTask merges dueDate and dueTime', () {
      final parsed = AIParsedTask.fromJson({
        'title': 'T',
        'priority': 'medium',
        'hasReminder': false,
        'dueDate': '2025-03-20',
        'dueTime': '09:00',
      }).toParsedTask();

      expect(parsed.dueDate, isNotNull);
      expect(parsed.dueDate!.year, 2025);
      expect(parsed.dueDate!.month, 3);
      expect(parsed.dueDate!.day, 20);
      expect(parsed.dueDate!.hour, 9);
      expect(parsed.dueDate!.minute, 0);
    });

    test('toParsedTask handles reminder offset', () {
      final parsed = AIParsedTask.fromJson({
        'title': 'T',
        'priority': 'medium',
        'hasReminder': true,
        'reminderOffsetMinutes': 30,
      }).toParsedTask();

      expect(parsed.hasReminder, true);
      expect(parsed.reminderOffset, isNotNull);
      expect(parsed.reminderOffset!.inMinutes, 30);
    });

    test('toParsedTask handles invalid dueDate gracefully', () {
      final parsed = AIParsedTask.fromJson({
        'title': 'T',
        'priority': 'medium',
        'hasReminder': false,
        'dueDate': 'not-a-date',
      }).toParsedTask();

      expect(parsed.dueDate, isNull);
    });

    test('toParsedTask defaults title if empty', () {
      final parsed = AIParsedTask.fromJson({
        'title': '',
        'priority': 'medium',
        'hasReminder': false,
      }).toParsedTask();

      expect(parsed.title, 'Untitled Task');
    });

    test('toSummary returns readable string', () {
      final task = AIParsedTask.fromJson({
        'title': 'Buy milk',
        'priority': 'high',
        'dueDate': '2025-01-15',
        'project': 'Home',
        'hasReminder': true,
        'reminderOffsetMinutes': 15,
      });

      final summary = task.toSummary();
      expect(summary, contains('Buy milk'));
      expect(summary, contains('high'));
      expect(summary, contains('Home'));
    });
  });

  group('AITaskParser._parseJsonResponse', () {
    test('parses clean JSON array', () {
      // Access private method via reflection isn't possible in Dart tests,
      // so we test through AIParsedTask directly
      final tasks = AIParsedTask.listFromJson([
        {'title': 'Task 1', 'priority': 'high', 'hasReminder': false}
      ]);
      expect(tasks.length, 1);
      expect(tasks[0].title, 'Task 1');
    });

    test('handles empty response', () {
      final tasks = AIParsedTask.listFromJson([]);
      expect(tasks, isEmpty);
    });

    test('parses multiple tasks', () {
      final tasks = AIParsedTask.listFromJson([
        {'title': 'A', 'priority': 'high', 'hasReminder': false},
        {'title': 'B', 'priority': 'low', 'hasReminder': true},
        {'title': 'C', 'priority': 'medium', 'hasReminder': false},
      ]);
      expect(tasks.length, 3);
      expect(tasks[0].title, 'A');
      expect(tasks[1].title, 'B');
      expect(tasks[2].title, 'C');
    });
  });
}
