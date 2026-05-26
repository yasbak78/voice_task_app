import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/parser/task_parser.dart';

void main() {
  group('TaskParser - Date/Time Parsing', () {
    test('today at 4pm — dueDate = today 16:00, title cleaned', () {
      final now = DateTime.now();
      final result = TaskParser.splitAndParse('Remind me to buy groceries today at 4pm');

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 1);

      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('buy groceries'));
      expect(task.hasReminder, isTrue);
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, now.year);
      expect(task.dueDate!.month, now.month);
      expect(task.dueDate!.day, now.day);
      expect(task.dueDate!.hour, 16);
      expect(task.dueDate!.minute, 0);
    });

    test('tomorrow at 10am — dueDate = tomorrow 10:00', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final result = TaskParser.splitAndParse('Call John tomorrow at 10am');

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 1);

      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('call john'));
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, tomorrow.year);
      expect(task.dueDate!.month, tomorrow.month);
      expect(task.dueDate!.day, tomorrow.day);
      expect(task.dueDate!.hour, 10);
      expect(task.dueDate!.minute, 0);
    });

    test('next Friday — dueDate = next Friday', () {
      final result = TaskParser.splitAndParse('Submit report next Friday');

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, 1);

      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('submit report'));
      expect(task.dueDate, isNotNull);

      // Verify it's a Friday (weekday == 5) and at least 7 days out
      expect(task.dueDate!.weekday, 5); // Friday
      final now = DateTime.now();
      final diff = task.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
      expect(diff, greaterThan(0));
    });

    test('at 3pm without date — dueDate = today 15:00', () {
      final now = DateTime.now();
      final result = TaskParser.splitAndParse('Review document at 3pm');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('review document'));
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, now.year);
      expect(task.dueDate!.month, now.month);
      expect(task.dueDate!.day, now.day);
      expect(task.dueDate!.hour, 15);
      expect(task.dueDate!.minute, 0);
    });

    test('high priority with tomorrow at 2pm', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final result = TaskParser.splitAndParse(
          'High priority: finish presentation tomorrow at 2pm');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.priority, Priority.high);
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, tomorrow.year);
      expect(task.dueDate!.month, tomorrow.month);
      expect(task.dueDate!.day, tomorrow.day);
      expect(task.dueDate!.hour, 14);
    });

    test('low priority with this weekend', () {
      final result = TaskParser.splitAndParse('Low priority clean the garage this weekend');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.priority, Priority.low);
      expect(task.dueDate, isNotNull);
      // "this weekend" maps to +5 days (Saturday)
      final now = DateTime.now();
      final expected = DateTime(now.year, now.month, now.day + 5);
      expect(task.dueDate!.day, expected.day);
    });

    test('multi-intent: two tasks detected', () {
      final result = TaskParser.splitAndParse('Buy milk and call dentist');

      expect(result.hasTasks, isTrue);
      expect(result.tasks.length, greaterThanOrEqualTo(2));
    });

    test('conversational input — no tasks', () {
      final result = TaskParser.splitAndParse('Hey how are you');

      expect(result.hasTasks, isFalse);
      expect(result.isConversational, isTrue);
      expect(result.conversationalReply, isNotNull);
    });

    test('set reminder — hasReminder=true with today at 9am', () {
      final now = DateTime.now();
      final result = TaskParser.splitAndParse('Set reminder for meeting today at 9am');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.hasReminder, isTrue);
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, now.year);
      expect(task.dueDate!.month, now.month);
      expect(task.dueDate!.day, now.day);
      expect(task.dueDate!.hour, 9);
    });

    test('am without dots is parsed correctly', () {
      final result = TaskParser.splitAndParse('Morning standup at 9am');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 9);
    });

    test('pm without dots is parsed correctly', () {
      final result = TaskParser.splitAndParse('Lunch meeting at 1pm');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 13);
    });

    test('a.m. with dots still works', () {
      final result = TaskParser.splitAndParse('Early call at 7 a.m.');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 7);
    });

    test('p.m. with dots still works', () {
      final result = TaskParser.splitAndParse('Evening review at 6 p.m.');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 18);
    });

    test('tomorrow without time — dueDate = tomorrow, no time component', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final result = TaskParser.splitAndParse('Finish report tomorrow');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, tomorrow.year);
      expect(task.dueDate!.month, tomorrow.month);
      expect(task.dueDate!.day, tomorrow.day);
    });

    test('today without time — dueDate = today', () {
      final now = DateTime.now();
      final result = TaskParser.splitAndParse('Do laundry today');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.year, now.year);
      expect(task.dueDate!.month, now.month);
      expect(task.dueDate!.day, now.day);
    });

    test('12am is midnight (hour 0)', () {
      final result = TaskParser.splitAndParse('Midnight task at 12am');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 0);
    });

    test('12pm is noon (hour 12)', () {
      final result = TaskParser.splitAndParse('Lunch at 12pm');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 12);
    });

    test('time with minutes — 3:30pm', () {
      final result = TaskParser.splitAndParse('Meeting at 3:30pm');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 15);
      expect(task.dueDate!.minute, 30);
    });

    test('next week — dueDate = +7 days', () {
      final now = DateTime.now();
      final nextWeek = DateTime(now.year, now.month, now.day + 7);
      final result = TaskParser.splitAndParse('Plan next week activities');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.day, nextWeek.day);
    });

    test('urgent priority detected', () {
      final result = TaskParser.splitAndParse('Urgent fix the server now');

      expect(result.hasTasks, isTrue);
      final task = result.tasks.first;
      expect(task.priority, Priority.high);
    });

    test('parserResult copyWith works', () {
      const original = ParsedTask(title: 'Test');
      final copy = original.copyWith(priority: Priority.high);
      expect(copy.title, 'Test');
      expect(copy.priority, Priority.high);
    });
  });
}
