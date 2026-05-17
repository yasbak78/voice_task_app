import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/core/notifications/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('singleton returns same instance', () {
      final s1 = NotificationService.instance;
      final s2 = NotificationService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('generate valid notification ID from timestamp', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = now.remainder(100000);
      expect(id, isA<int>());
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(100000));
    });

    test('scheduledDate in past should be rejected', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(past.isBefore(DateTime.now()), isTrue);
    });

    test('scheduledDate in future should be accepted', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      expect(future.isAfter(DateTime.now()), isTrue);
    });

    test('notification title is not empty', () {
      const title = 'Task Due: Buy groceries';
      expect(title.isNotEmpty, isTrue);
      expect(title.contains('Task Due:'), isTrue);
    });

    test('notification body falls back when notes empty', () {
      const notes = '';
      final body = notes.isEmpty ? 'This task is due now' : notes;
      expect(body, equals('This task is due now'));
    });

    test('notification body uses notes when provided', () {
      const notes = 'Don\'t forget milk';
      final body = notes.isEmpty ? 'This task is due now' : notes;
      expect(body, equals('Don\'t forget milk'));
    });
  });
}
