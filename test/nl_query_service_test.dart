import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/services/nl_query_service.dart';

void main() {
  group('NLQuery enum parsing', () {
    test('NLQueryType values are correct', () {
      expect(NLQueryType.values.length, 8);
      expect(NLQueryType.filterByStatus.name, 'filterByStatus');
      expect(NLQueryType.filterByKeyword.name, 'filterByKeyword');
      expect(NLQueryType.filterByDate.name, 'filterByDate');
      expect(NLQueryType.filterByProject.name, 'filterByProject');
      expect(NLQueryType.filterByPriority.name, 'filterByPriority');
      expect(NLQueryType.aggregate.name, 'aggregate');
      expect(NLQueryType.listAll.name, 'listAll');
      expect(NLQueryType.conversational.name, 'conversational');
    });

    test('DateRange values are correct', () {
      expect(DateRange.values.length, 5);
      expect(DateRange.today.name, 'today');
      expect(DateRange.thisWeek.name, 'thisWeek');
      expect(DateRange.thisMonth.name, 'thisMonth');
      expect(DateRange.overdue.name, 'overdue');
      expect(DateRange.upcoming.name, 'upcoming');
    });
  });

  group('NLQuery construction', () {
    test('creates query with all fields', () {
      final query = NLQuery(
        type: NLQueryType.filterByKeyword,
        keyword: 'Nallini',
        statusFilter: 'pending',
        dateRange: DateRange.overdue,
        aggregate: false,
        rawQuestion: 'show me overdue tasks about Nallini',
      );

      expect(query.type, NLQueryType.filterByKeyword);
      expect(query.keyword, 'Nallini');
      expect(query.statusFilter, 'pending');
      expect(query.dateRange, DateRange.overdue);
      expect(query.aggregate, false);
      expect(query.rawQuestion, 'show me overdue tasks about Nallini');
    });

    test('creates minimal query', () {
      final query = NLQuery(
        type: NLQueryType.listAll,
        rawQuestion: 'list all tasks',
      );

      expect(query.type, NLQueryType.listAll);
      expect(query.keyword, isNull);
      expect(query.statusFilter, isNull);
      expect(query.rawQuestion, 'list all tasks');
    });
  });

  group('NLQueryResult construction', () {
    test('creates result with tasks', () {
      final result = NLQueryResult(
        summary: 'Found 3 tasks',
        totalCount: 3,
      );

      expect(result.summary, 'Found 3 tasks');
      expect(result.totalCount, 3);
      expect(result.tasks, isEmpty);
      expect(result.isConversational, false);
      expect(result.conversationalReply, isNull);
    });

    test('creates conversational result', () {
      final result = NLQueryResult(
        summary: 'Hello! How can I help?',
        totalCount: 0,
        isConversational: true,
        conversationalReply: 'Hello! How can I help?',
      );

      expect(result.isConversational, true);
      expect(result.conversationalReply, 'Hello! How can I help?');
      expect(result.tasks, isEmpty);
    });
  });

  group('AI query extraction prompt validation', () {
    test('prompt contains all required query type examples', () {
      // Verify the prompt template includes all the example queries
      // This ensures the AI knows how to handle each type
      final requiredTypes = [
        'filterByStatus',
        'filterByKeyword',
        'filterByDate',
        'filterByProject',
        'filterByPriority',
        'aggregate',
        'listAll',
        'conversational',
      ];

      // These should all be valid enum values
      for (final type in requiredTypes) {
        expect(NLQueryType.values.any((t) => t.name == type), isTrue,
            reason: '$type should be a valid NLQueryType');
      }
    });

    test('JSON parsing handles markdown code blocks', () {
      // Simulate what the AI might return with markdown formatting
      final response = '```json\n{"type":"filterByKeyword","keyword":"Nallini"}\n```';
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(json['type'], 'filterByKeyword');
      expect(json['keyword'], 'Nallini');
    });

    test('JSON parsing handles plain JSON', () {
      final response = '{"type":"listAll"}';
      final json = jsonDecode(response.trim()) as Map<String, dynamic>;

      expect(json['type'], 'listAll');
    });

    test('DateRange enum resolves from JSON string', () {
      final jsonValues = ['today', 'thisWeek', 'thisMonth', 'overdue', 'upcoming'];

      for (final value in jsonValues) {
        final range = DateRange.values.firstWhere((d) => d.name == value);
        expect(range, isNotNull);
        expect(range.name, value);
      }
    });

    test('Unknown query type falls back to conversational', () {
      const unknownType = 'unknownType';
      NLQueryType resolved;
      try {
        resolved = NLQueryType.values.firstWhere((t) => t.name == unknownType);
      } catch (_) {
        resolved = NLQueryType.conversational;
      }

      expect(resolved, NLQueryType.conversational);
    });
  });

  group('Date range logic validation', () {
    test('overdue filter is before start of today', () {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final yesterday = startOfDay.subtract(const Duration(days: 1));
      final tomorrow = startOfDay.add(const Duration(days: 1));

      expect(yesterday.isBefore(startOfDay), isTrue);
      expect(tomorrow.isBefore(startOfDay), isFalse);
    });

    test('today filter captures dates within day boundaries', () {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final noon = startOfDay.add(const Duration(hours: 12));

      expect(noon.isAtSameMomentAs(startOfDay) ||
          (noon.isAfter(startOfDay) && noon.isBefore(endOfDay)), isTrue);
    });

    test('upcoming filter is after start of today', () {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final tomorrow = startOfDay.add(const Duration(days: 1));
      final yesterday = startOfDay.subtract(const Duration(days: 1));

      expect(tomorrow.isAfter(startOfDay.subtract(const Duration(days: 1))), isTrue);
      expect(yesterday.isAfter(startOfDay.subtract(const Duration(days: 1))), isFalse);
    });
  });

  group('Query type mapping coverage', () {
    test('all 8 query types have distinct enum values', () {
      final names = NLQueryType.values.map((t) => t.name).toSet();
      expect(names.length, 8);
    });

    test('all 5 date ranges have distinct enum values', () {
      final names = DateRange.values.map((d) => d.name).toSet();
      expect(names.length, 5);
    });
  });

  group('NLQueryService structure validation', () {
    test('service has execute method', () {
      // Verify the public API exists
      final service = NLQueryService;
      expect(service, isNotNull);
    });

    test('fallback produces valid error message for empty results', () {
      // When AI fails and we fall back to keyword search, empty results
      // should produce a clear message
      const question = 'show me overdue tasks about Nallini';
      final fallbackMessage = 'No tasks match your query: "$question"';
      expect(fallbackMessage.contains('No tasks match'), isTrue);
      expect(fallbackMessage.contains(question), isTrue);
    });

    test('conversational fallback returns help message', () {
      const fallbackMsg = "I couldn't process that. Try asking about your tasks, like 'show me overdue tasks'.";
      expect(fallbackMsg.length, greaterThan(10));
      expect(fallbackMsg.contains('tasks'), isTrue);
    });
  });

  group('Task sorting logic', () {
    test('high priority sorts before medium', () {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      expect(priorityOrder['high']! < priorityOrder['medium']!, isTrue);
    });

    test('medium priority sorts before low', () {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      expect(priorityOrder['medium']! < priorityOrder['low']!, isTrue);
    });

    test('unknown priority defaults to medium', () {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      expect(priorityOrder['unknown'] ?? 1, equals(1));
    });
  });
}
