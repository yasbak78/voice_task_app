import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_task_app/models/token_usage.dart';
import 'package:voice_task_app/services/token_tracker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('TokenUsage', () {
    test('creates from JSON', () {
      final usage = TokenUsage.fromJson({
        'prompt_tokens': 100,
        'completion_tokens': 50,
        'total_tokens': 150,
        'timestamp': '2026-05-28T10:00:00Z',
        'provider': 'Groq',
        'model': 'llama-3.3-70b',
        'purpose': 'task_parse',
      });

      expect(usage.promptTokens, 100);
      expect(usage.completionTokens, 50);
      expect(usage.totalTokens, 150);
      expect(usage.provider, 'Groq');
      expect(usage.purpose, 'task_parse');
    });

    test('serializes to JSON', () {
      final usage = TokenUsage(
        promptTokens: 200,
        completionTokens: 80,
        totalTokens: 280,
        timestamp: DateTime(2026, 5, 28, 10, 0, 0),
        provider: 'OpenRouter',
        model: 'anthropic/claude-sonnet-4-20250514',
        purpose: 'scheduling',
      );

      final json = usage.toJson();
      expect(json['prompt_tokens'], 200);
      expect(json['completion_tokens'], 80);
      expect(json['total_tokens'], 280);
      expect(json['provider'], 'OpenRouter');
      expect(json['purpose'], 'scheduling');
    });

    test('handles missing fields with defaults', () {
      final usage = TokenUsage.fromJson({});
      expect(usage.promptTokens, 0);
      expect(usage.completionTokens, 0);
      expect(usage.totalTokens, 0);
      expect(usage.provider, 'unknown');
    });
  });

  group('TokenSummary', () {
    test('formatTokens converts large numbers', () {
      expect(TokenSummary.formatTokens(500), '500');
      expect(TokenSummary.formatTokens(1500), '1.5K');
      expect(TokenSummary.formatTokens(1500000), '1.5M');
    });

    test('toSummaryString includes all sections', () {
      final summary = TokenSummary(
        promptTokens: 1000,
        completionTokens: 500,
        totalTokens: 1500,
        requestCount: 10,
        byProvider: {'Groq': 1200, 'OpenRouter': 300},
        byPurpose: {'task_parse': 5, 'scheduling': 3, 'nl_query': 2},
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      );

      final str = summary.toSummaryString();
      expect(str.contains('10 requests'), isTrue);
      expect(str.contains('1.5K'), isTrue);
      expect(str.contains('Groq'), isTrue);
      expect(str.contains('task_parse'), isTrue);
    });
  });

  group('TokenTracker', () {
    test('records and retrieves usage', () async {
      await TokenTracker.clear();

      final usage = TokenUsage(
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
        timestamp: DateTime.now(),
        provider: 'Groq',
        model: 'llama-3.3-70b',
        purpose: 'task_parse',
      );

      await TokenTracker.record(usage);
      final records = await TokenTracker.getUsage();

      expect(records.length, 1);
      expect(records.first.totalTokens, 150);
      expect(records.first.provider, 'Groq');
      expect(records.first.purpose, 'task_parse');
    });

    test('summary aggregates correctly', () async {
      await TokenTracker.clear();

      await TokenTracker.record(TokenUsage(
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
        timestamp: DateTime.now(),
        provider: 'Groq',
        model: 'llama-3.3-70b',
        purpose: 'task_parse',
      ));

      await TokenTracker.record(TokenUsage(
        promptTokens: 200,
        completionTokens: 80,
        totalTokens: 280,
        timestamp: DateTime.now(),
        provider: 'Groq',
        model: 'llama-3.3-70b',
        purpose: 'scheduling',
      ));

      await TokenTracker.record(TokenUsage(
        promptTokens: 50,
        completionTokens: 25,
        totalTokens: 75,
        timestamp: DateTime.now(),
        provider: 'OpenRouter',
        model: 'anthropic/claude-sonnet-4',
        purpose: 'nl_query',
      ));

      final summary = await TokenTracker.getSummary();

      expect(summary.requestCount, 3);
      expect(summary.totalTokens, 505);
      expect(summary.promptTokens, 350);
      expect(summary.completionTokens, 155);
      expect(summary.byProvider['Groq'], 430);
      expect(summary.byProvider['OpenRouter'], 75);
      expect(summary.byPurpose['task_parse'], 1);
      expect(summary.byPurpose['scheduling'], 1);
      expect(summary.byPurpose['nl_query'], 1);
    });

    test('clear removes all records', () async {
      await TokenTracker.clear();

      await TokenTracker.record(TokenUsage(
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
        timestamp: DateTime.now(),
        provider: 'Test',
        model: 'test',
        purpose: 'test',
      ));

      var records = await TokenTracker.getUsage();
      expect(records.length, 1);

      await TokenTracker.clear();
      records = await TokenTracker.getUsage();
      expect(records.length, 0);
    });
  });
}
