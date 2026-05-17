import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/core/parser/task_parser.dart';

void main() {
  group('TaskParser.parse — basic', () {
    test('parses simple task title', () {
      final result = TaskParser.parse('Buy groceries');
      expect(result.title, 'Buy groceries');
      expect(result.priority, Priority.medium);
      expect(result.project, isNull);
      expect(result.dueDate, isNull);
    });

    test('parses task with high priority', () {
      final result = TaskParser.parse('Urgent: Submit tax report');
      expect(result.priority, Priority.high);
      expect(result.title.contains('Urgent'), isFalse);
    });

    test('parses task with low priority', () {
      final result = TaskParser.parse('Clean the garage whenever');
      expect(result.priority, Priority.low);
    });

    test('parses task with default medium priority', () {
      final result = TaskParser.parse('Read chapter 3');
      expect(result.priority, Priority.medium);
    });

    test('strips filler words from start', () {
      final result = TaskParser.parse('Um so I need to call John');
      expect(result.title, 'Call John');
    });

    test('strips multiple filler words', () {
      final result = TaskParser.parse('Hey uh so like I wanna schedule a meeting');
      expect(result.title.contains('Hey'), isFalse);
      expect(result.title.contains('wanna'), isFalse);
    });
  });

  group('TaskParser.parse — date extraction', () {
    test('parses "tomorrow"', () {
      final result = TaskParser.parse('Submit report tomorrow');
      expect(result.dueDate, isNotNull);
      final tomorrow = DateTime.now();
      expect(result.dueDate!.day, equals((tomorrow.day + 1) % 31));
    });

    test('parses "next week"', () {
      final result = TaskParser.parse('Team standup next week');
      expect(result.dueDate, isNotNull);
    });

    test('parses "today"', () {
      final result = TaskParser.parse('Call dentist today');
      expect(result.dueDate, isNotNull);
      expect(result.dueDate!.day, DateTime.now().day);
    });

    test('parses explicit time', () {
      final result = TaskParser.parse('Meeting at 3pm');
      expect(result.dueDate, isNotNull);
      expect(result.dueDate!.hour, 15);
      expect(result.dueDate!.minute, 0);
    });

    test('parses time with minutes', () {
      final result = TaskParser.parse('Call at 9:30am');
      expect(result.dueDate, isNotNull);
      expect(result.dueDate!.hour, 9);
      expect(result.dueDate!.minute, 30);
    });
  });

  group('TaskParser.parse — project extraction', () {
    test('extracts project from "for the marketing project"', () {
      final result = TaskParser.parse('Design banner for the marketing project');
      expect(result.project, isNotNull);
      expect(result.project!.toLowerCase(), contains('marketing'));
    });

    test('extracts project from hashtag format', () {
      final result = TaskParser.parse('Fix login #mobile-app');
      expect(result.project, 'mobile-app');
    });

    test('does not extract project when absent', () {
      final result = TaskParser.parse('Buy milk');
      expect(result.project, isNull);
    });
  });

  group('TaskParser.parse — reminder extraction', () {
    test('detects reminder flag', () {
      final result = TaskParser.parse('Remind me to call mom');
      expect(result.hasReminder, isTrue);
    });

    test('detects "set a reminder"', () {
      final result = TaskParser.parse('Set a reminder for dentist');
      expect(result.hasReminder, isTrue);
    });

    test('no reminder when not mentioned', () {
      final result = TaskParser.parse('Write blog post');
      expect(result.hasReminder, isFalse);
    });
  });

  group('TaskParser.parse — title cleanup', () {
    test('splits long text into title + notes', () {
      final result = TaskParser.parse(
        'Complete the quarterly budget review and send it to the finance team by Friday',
      );
      expect(result.title.length, lessThanOrEqualTo(40));
      expect(result.notes, isNotNull);
    });

    test('caps title at 40 chars with word boundary', () {
      final result = TaskParser.parse(
        'This is a really long task description that needs to be split',
      );
      expect(result.title.length, lessThanOrEqualTo(40));
    });

    test('removes trailing please/thanks', () {
      final result = TaskParser.parse('Send the email please');
      expect(result.title.toLowerCase().contains('please'), isFalse);
    });

    test('capitalizes first letter', () {
      final result = TaskParser.parse('update the README file');
      expect(result.title[0], result.title[0].toUpperCase());
    });

    test('removes trailing punctuation', () {
      final result = TaskParser.parse('Fix the login bug.');
      expect(result.title.endsWith('.'), isFalse);
    });
  });

  group('TaskParser.splitAndParse — multi-intent', () {
    test('splits on "and also"', () {
      final result = TaskParser.splitAndParse(
        'Buy groceries and also schedule dentist appointment',
      );
      expect(result.tasks.length, greaterThanOrEqualTo(2));
      expect(result.isConversational, isFalse);
    });

    test('splits on period separator', () {
      final result = TaskParser.splitAndParse(
        'Call John. Then email the client.',
      );
      expect(result.tasks.length, greaterThanOrEqualTo(1));
    });
  });

  group('TaskParser.splitAndParse — conversational', () {
    test('detects "how are you"', () {
      final result = TaskParser.splitAndParse('Hey, how are you?');
      expect(result.isConversational, isTrue);
      expect(result.conversationalReply, isNotNull);
    });

    test('detects "good morning"', () {
      final result = TaskParser.splitAndParse('Good morning!');
      expect(result.isConversational, isTrue);
    });

    test('task-like text is NOT conversational', () {
      final result = TaskParser.splitAndParse('Good morning, I need to schedule a meeting');
      expect(result.isConversational, isFalse);
      expect(result.hasTasks, isTrue);
    });

    test('detects "thank you"', () {
      final result = TaskParser.splitAndParse('Thank you so much');
      expect(result.isConversational, isTrue);
    });
  });

  group('TaskParser.parse — combined attributes', () {
    test('parses task with priority, project, and date', () {
      final result = TaskParser.parse(
        'Urgent: review the design for the website project tomorrow',
      );
      expect(result.priority, Priority.high);
      expect(result.project, isNotNull);
      expect(result.dueDate, isNotNull);
    });

    test('parses complex task with reminder and time', () {
      final result = TaskParser.parse(
        'Remind me to call client at 2pm',
      );
      expect(result.hasReminder, isTrue);
      expect(result.dueDate, isNotNull);
      expect(result.dueDate!.hour, 14);
    });
  });

  group('ParsedTask', () {
    test('copyWith updates fields', () {
      final task = const ParsedTask(title: 'Test');
      final updated = task.copyWith(
        priority: Priority.high,
        notes: 'Important note',
      );
      expect(updated.title, 'Test');
      expect(updated.priority, Priority.high);
      expect(updated.notes, 'Important note');
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime.now();
      final task = ParsedTask(
        title: 'Original',
        priority: Priority.low,
        dueDate: now,
      );
      final updated = task.copyWith(title: 'Changed');
      expect(updated.title, 'Changed');
      expect(updated.priority, Priority.low);
      expect(updated.dueDate, now);
    });
  });

  group('ParserResult', () {
    test('isConversational when no tasks', () {
      final result = const ParserResult(
        tasks: [],
        conversationalReply: 'Hello!',
      );
      expect(result.isConversational, isTrue);
      expect(result.hasTasks, isFalse);
    });

    test('hasTasks when tasks present', () {
      final result = ParserResult(
        tasks: [const ParsedTask(title: 'Task 1')],
      );
      expect(result.hasTasks, isTrue);
      expect(result.isConversational, isFalse);
    });
  });
}
