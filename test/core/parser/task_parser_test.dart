import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/core/database/app_database.dart';
import 'package:voice_task_app/core/parser/task_parser.dart';

void main() {
  group('TaskParser - Single Task Parsing', () {
    test('parses title, date, and time from "buy groceries today at 4pm"', () {
      final result = TaskParser.splitAndParse('buy groceries today at 4pm');
      expect(result.hasTasks, true);
      expect(result.tasks.length, 1);

      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('groceries'));
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.day, DateTime.now().day);
      expect(task.dueDate!.month, DateTime.now().month);
      expect(task.dueDate!.hour, 16); // 4pm = 16:00
      expect(task.dueDate!.minute, 0);
    });

    test('parses "remind me to call John tomorrow at 10am"', () {
      final result = TaskParser.splitAndParse('remind me to call John tomorrow at 10am');
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.hasReminder, true);
      expect(task.title.toLowerCase(), contains('john'));
      expect(task.dueDate, isNotNull);
      // tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(task.dueDate!.day, tomorrow.day);
      expect(task.dueDate!.month, tomorrow.month);
      expect(task.dueDate!.hour, 10);
      expect(task.dueDate!.minute, 0);
    });

    test('parses "submit report at 3pm" (date defaults to today)', () {
      final result = TaskParser.splitAndParse('submit report at 3pm');
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 15); // 3pm = 15:00
      expect(task.dueDate!.day, DateTime.now().day);
    });

    test('parses "review document next friday"', () {
      final result = TaskParser.splitAndParse('review document next friday');
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.title.toLowerCase(), contains('document'));
      expect(task.dueDate, isNotNull);
      // next friday should be 7-14 days from now (minimum 7 when today is Thursday)
      final diff = task.dueDate!.difference(DateTime.now()).inDays;
      expect(diff, greaterThanOrEqualTo(7));
      expect(diff, lessThanOrEqualTo(14));
      // Friday is weekday 5
      expect(task.dueDate!.weekday, 5);
    });

    test('parses "today" as current date', () {
      final result = TaskParser.splitAndParse('exercise today');
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.day, DateTime.now().day);
      expect(task.dueDate!.month, DateTime.now().month);
    });

    test('parses "tomorrow" as next day', () {
      final result = TaskParser.splitAndParse('pay bills tomorrow');
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(task.dueDate!.day, tomorrow.day);
      expect(task.dueDate!.month, tomorrow.month);
    });
  });

  group('TaskParser - Time Parsing', () {
    test('parses 12pm as noon (12:00)', () {
      final result = TaskParser.splitAndParse('lunch meeting at 12pm');
      expect(result.tasks.first.dueDate!.hour, 12);
      expect(result.tasks.first.dueDate!.minute, 0);
    });

    test('parses 12am as midnight (00:00)', () {
      final result = TaskParser.splitAndParse('midnight snack at 12am');
      expect(result.tasks.first.dueDate!.hour, 0);
      expect(result.tasks.first.dueDate!.minute, 0);
    });

    test('parses 11:30pm correctly (23:30)', () {
      final result = TaskParser.splitAndParse('watch movie at 11:30pm');
      expect(result.tasks.first.dueDate!.hour, 23);
      expect(result.tasks.first.dueDate!.minute, 30);
    });

    test('parses "a.m." format (with dots)', () {
      final result = TaskParser.splitAndParse('morning standup at 9 a.m.');
      expect(result.tasks.first.dueDate!.hour, 9);
    });

    test('parses "p.m." format (with dots)', () {
      final result = TaskParser.splitAndParse('afternoon review at 2 p.m.');
      expect(result.tasks.first.dueDate!.hour, 14);
    });

    test('parses time with "at" prefix', () {
      final result = TaskParser.splitAndParse('meeting at 3pm');
      expect(result.tasks.first.dueDate!.hour, 15);
    });

    test('parses time without "at" prefix', () {
      final result = TaskParser.splitAndParse('meeting 3pm');
      expect(result.tasks.first.dueDate!.hour, 15);
    });

    // Voice-to-text frequently drops colons — test alternate formats
    test('parses dot separator: 1.45pm', () {
      final result = TaskParser.splitAndParse('bring jacket at 1.45pm');
      expect(result.tasks.first.dueDate!.hour, 13);
      expect(result.tasks.first.dueDate!.minute, 45);
    });

    test('parses concatenated 3-digit: 145pm → 1:45pm', () {
      final result = TaskParser.splitAndParse('bring jacket at 145pm');
      expect(result.tasks.first.dueDate!.hour, 13);
      expect(result.tasks.first.dueDate!.minute, 45);
    });

    test('parses concatenated 4-digit: 1230pm → 12:30pm', () {
      final result = TaskParser.splitAndParse('lunch at 1230pm');
      expect(result.tasks.first.dueDate!.hour, 12);
      expect(result.tasks.first.dueDate!.minute, 30);
    });

    test('parses concatenated 3-digit AM: 952am → 9:52am', () {
      final result = TaskParser.splitAndParse('morning standup at 952am');
      expect(result.tasks.first.dueDate!.hour, 9);
      expect(result.tasks.first.dueDate!.minute, 52);
    });

    test('parses dot separator with AM: 1.52am', () {
      final result = TaskParser.splitAndParse('red-eye flight at 1.52am');
      expect(result.tasks.first.dueDate!.hour, 1);
      expect(result.tasks.first.dueDate!.minute, 52);
    });

    test('parses space separator: 4 30pm → 4:30pm', () {
      final result = TaskParser.splitAndParse('gym session at 4 30pm');
      expect(result.tasks.first.dueDate!.hour, 16);
      expect(result.tasks.first.dueDate!.minute, 30);
    });
  });

  group('TaskParser - Relative Time', () {
    test('parses "in 10 minutes" — dueDate ≈ now + 10 min', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('take out the trash in 10 minutes');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 9))), true);
      expect(due.isBefore(after.add(Duration(minutes: 11))), true);
    });

    test('parses "in 1 hour" — dueDate ≈ now + 60 min', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('join meeting in 1 hour');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 59))), true);
      expect(due.isBefore(after.add(Duration(minutes: 61))), true);
    });

    test('parses "in 2 hours" — dueDate ≈ now + 120 min', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('call dentist in 2 hours');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 119))), true);
      expect(due.isBefore(after.add(Duration(minutes: 121))), true);
    });

    test('parses "in 30 min" — abbreviated unit', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('check oven in 30 min');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 29))), true);
      expect(due.isBefore(after.add(Duration(minutes: 31))), true);
    });

    test('parses "in half an hour" — dueDate ≈ now + 30 min', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('water plants in half an hour');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 29))), true);
      expect(due.isBefore(after.add(Duration(minutes: 31))), true);
    });

    test('parses "in 15 mins" — plural abbreviated', () {
      final before = DateTime.now();
      final result = TaskParser.splitAndParse('pause laundry in 15 mins');
      final after = DateTime.now();
      final due = result.tasks.first.dueDate!;
      expect(due.isAfter(before.add(Duration(minutes: 14))), true);
      expect(due.isBefore(after.add(Duration(minutes: 16))), true);
    });

    test('title is cleaned after extracting relative time', () {
      final result = TaskParser.splitAndParse('remind me to call mom in 10 minutes');
      // "remind me" is extracted as hasReminder=true, title becomes "To call mom"
      expect(result.tasks.first.hasReminder, true);
      expect(result.tasks.first.title, 'To call mom');
    });
  });

  group('TaskParser - Priority Extraction', () {
    test('detects high priority with "urgent"', () {
      final result = TaskParser.splitAndParse('urgent fix the server');
      expect(result.tasks.first.priority, Priority.high);
    });

    test('detects high priority with "asap"', () {
      final result = TaskParser.splitAndParse('send email asap');
      expect(result.tasks.first.priority, Priority.high);
    });

    test('detects high priority with "high priority"', () {
      final result = TaskParser.splitAndParse('high priority review code');
      expect(result.tasks.first.priority, Priority.high);
    });

    test('detects low priority with "no rush"', () {
      final result = TaskParser.splitAndParse('organize files no rush');
      expect(result.tasks.first.priority, Priority.low);
    });

    test('defaults to medium priority', () {
      final result = TaskParser.splitAndParse('buy groceries tomorrow');
      expect(result.tasks.first.priority, Priority.medium);
    });
  });

  group('TaskParser - Reminder Extraction', () {
    test('detects "remind me"', () {
      final result = TaskParser.splitAndParse('remind me to call mom');
      expect(result.tasks.first.hasReminder, true);
    });

    test('detects "set a reminder"', () {
      final result = TaskParser.splitAndParse('set a reminder for the meeting');
      expect(result.tasks.first.hasReminder, true);
    });

    test('does not set reminder without reminder keywords', () {
      final result = TaskParser.splitAndParse('buy milk tomorrow');
      expect(result.tasks.first.hasReminder, false);
    });
  });

  group('TaskParser - Multi-Task Parsing', () {
    test('splits two tasks with "and"', () {
      final result = TaskParser.splitAndParse(
        'buy groceries and also call the dentist',
      );
      expect(result.hasTasks, true);
      expect(result.tasks.length, greaterThanOrEqualTo(2));
      expect(result.tasks[0].title.toLowerCase(), contains('groceries'));
      expect(result.tasks[1].title.toLowerCase(), contains('dentist'));
    });

    test('splits tasks with period separator', () {
      final result = TaskParser.splitAndParse(
        'Buy milk. Also send the report.',
      );
      expect(result.hasTasks, true);
      expect(result.tasks.length, greaterThanOrEqualTo(2));
    });

    test('single task returns one result', () {
      final result = TaskParser.splitAndParse('just one task');
      expect(result.hasTasks, true);
      expect(result.tasks.length, 1);
    });
  });

  group('TaskParser - Conversational Detection', () {
    test('recognizes "how are you" as conversational', () {
      final result = TaskParser.splitAndParse('hey how are you');
      expect(result.isConversational, true);
      expect(result.conversationalReply, isNotNull);
    });

    test('recognizes "good morning" as conversational', () {
      final result = TaskParser.splitAndParse('good morning');
      expect(result.isConversational, true);
    });

    test('recognizes "thank you" as conversational', () {
      final result = TaskParser.splitAndParse('thank you');
      expect(result.isConversational, true);
    });
  });

  group('TaskParser - Title Cleaning', () {
    test('strips filler words from start', () {
      final result = TaskParser.splitAndParse(
        'I need to please remind me to buy groceries',
      );
      final task = result.tasks.first;
      // Should not contain filler phrases
      expect(task.title.toLowerCase(), isNot(startsWith('i need to')));
    });

    test('capitalizes first letter', () {
      final result = TaskParser.splitAndParse('buy groceries');
      expect(result.tasks.first.title[0], equals(result.tasks.first.title[0].toUpperCase()));
    });

    test('removes trailing punctuation', () {
      final result = TaskParser.splitAndParse('buy groceries.');
      expect(result.tasks.first.title.endsWith('.'), false);
    });
  });

  group('TaskParser - Complex Voice Inputs (Realistic)', () {
    test('remind me to buy groceries today at 4 p.m.', () {
      final result = TaskParser.splitAndParse(
        'remind me to buy groceries today at 4 p.m.',
      );
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.hasReminder, true);
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.hour, 16);
      expect(task.dueDate!.day, DateTime.now().day);
      expect(task.title.toLowerCase(), contains('groceries'));
    });

    test('urgent call client next monday at 9am and set reminder', () {
      final result = TaskParser.splitAndParse(
        'urgent call client next monday at 9am and set reminder',
      );
      expect(result.hasTasks, true);
      final task = result.tasks.first;
      expect(task.priority, Priority.high);
      expect(task.hasReminder, true);
      expect(task.dueDate!.weekday, 1); // Monday
      expect(task.dueDate!.hour, 9);
    });

    test('low priority read book this weekend', () {
      final result = TaskParser.splitAndParse(
        'low priority read book this weekend',
      );
      expect(result.tasks.first.priority, Priority.low);
      expect(result.tasks.first.dueDate, isNotNull);
      // this weekend = +5 days (Saturday)
      final diff = result.tasks.first.dueDate!.difference(DateTime.now()).inDays;
      expect(diff, greaterThanOrEqualTo(0));
      expect(diff, lessThanOrEqualTo(7));
    });

    test('multi-task: each task gets its own time', () {
      final result = TaskParser.splitAndParse(
        'meeting tomorrow at 9am and call John at 2pm',
      );
      expect(result.hasTasks, true);
      expect(result.tasks.length, greaterThanOrEqualTo(2));
      // Task 1: tomorrow at 9am
      final task1 = result.tasks[0];
      expect(task1.dueDate!.hour, 9);
      expect(task1.dueDate!.minute, 0);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(task1.dueDate!.day, tomorrow.day);
      expect(task1.dueTime, isNotNull);
      expect(task1.dueTime!.hour, 9);
      // Task 2: at 2pm (date defaults to today)
      final task2 = result.tasks[1];
      expect(task2.dueDate!.hour, 14);
      expect(task2.dueDate!.minute, 0);
      expect(task2.dueDate!.day, DateTime.now().day);
      expect(task2.dueTime, isNotNull);
      expect(task2.dueTime!.hour, 14);
    });

    test('multi-task: time only parsed when explicitly stated', () {
      final result = TaskParser.splitAndParse(
        'meeting tomorrow and call John at 3pm',
      );
      expect(result.tasks.length, greaterThanOrEqualTo(2));
      // Task 1: no time stated
      expect(result.tasks[0].dueTime, isNull);
      // Task 2: has time
      expect(result.tasks[1].dueTime, isNotNull);
      expect(result.tasks[1].dueTime!.hour, 15);
    });
  });
}
