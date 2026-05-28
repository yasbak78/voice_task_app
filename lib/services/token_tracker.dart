import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token_usage.dart';

/// Tracks and persists AI token usage across sessions.
///
/// Stores usage records in SharedPreferences with daily aggregation.
/// Automatically prunes records older than 90 days.
class TokenTracker {
  static const _key = 'token_usage_records';
  static const _maxAgeDays = 90;

  TokenTracker._();

  /// Record a single API request's token usage.
  static Future<void> record(TokenUsage usage) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _loadAll(prefs);

    // Prune old records
    final cutoff = DateTime.now().subtract(const Duration(days: _maxAgeDays));
    records.removeWhere((r) => r.timestamp.isBefore(cutoff));

    records.add(usage);
    await _saveAll(prefs, records);
  }

  /// Get all records within a date range (defaults to last 7 days).
  static Future<List<TokenUsage>> getUsage({
    DateTime? start,
    DateTime? end,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _loadAll(prefs);

    start ??= DateTime.now().subtract(const Duration(days: 7));
    end ??= DateTime.now().add(const Duration(days: 1));

    return records
        .where((r) => !r.timestamp.isBefore(start!) && !r.timestamp.isAfter(end!))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get aggregated usage totals for a period.
  static Future<TokenSummary> getSummary({DateTime? start, DateTime? end}) async {
    final records = await getUsage(start: start, end: end);

    int promptTokens = 0;
    int completionTokens = 0;
    int totalTokens = 0;
    int requestCount = records.length;

    final byProvider = <String, int>{};
    final byPurpose = <String, int>{};

    for (final r in records) {
      promptTokens += r.promptTokens;
      completionTokens += r.completionTokens;
      totalTokens += r.totalTokens;
      byProvider[r.provider] = (byProvider[r.provider] ?? 0) + r.totalTokens;
      byPurpose[r.purpose] = (byPurpose[r.purpose] ?? 0) + 1;
    }

    return TokenSummary(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      requestCount: requestCount,
      byProvider: byProvider,
      byPurpose: byPurpose,
      start: start ?? DateTime.now().subtract(const Duration(days: 7)),
      end: end ?? DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// Get today's token usage broken down by provider.
  static Future<Map<String, int>> getTodayUsageByProvider() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final records = await getUsage(start: todayStart, end: todayEnd);

    final byProvider = <String, int>{};
    for (final r in records) {
      byProvider[r.provider] = (byProvider[r.provider] ?? 0) + r.totalTokens;
    }
    return byProvider;
  }

  /// Get today's total tokens for a specific provider (synchronous-friendly).
  static Future<int> getTodayTotalTokens(String provider) async {
    final usage = await getTodayUsageByProvider();
    return usage[provider] ?? 0;
  }

  /// Clear all stored usage data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static List<TokenUsage> _loadAll(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TokenUsage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(
    SharedPreferences prefs,
    List<TokenUsage> records,
  ) async {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(_key, json);
  }
}

/// Aggregated token usage summary.
class TokenSummary {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int requestCount;
  final Map<String, int> byProvider;
  final Map<String, int> byPurpose;
  final DateTime start;
  final DateTime end;

  const TokenSummary({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.requestCount,
    required this.byProvider,
    required this.byPurpose,
    required this.start,
    required this.end,
  });

  /// Format token count with K/M suffix for readability.
  static String formatTokens(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  /// Human-readable summary string.
  String toSummaryString() {
    final days = end.difference(start).inDays;
    final lines = <String>[];
    lines.add('$requestCount requests in ${days <= 0 ? '1' : days}d');
    lines.add('${formatTokens(totalTokens)} total tokens');
    lines.add('  prompt: ${formatTokens(promptTokens)}');
    lines.add('  completion: ${formatTokens(completionTokens)}');

    if (byProvider.isNotEmpty) {
      lines.add('By provider:');
      for (final e in byProvider.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
        lines.add('  ${e.key}: ${formatTokens(e.value)}');
      }
    }

    if (byPurpose.isNotEmpty) {
      lines.add('By purpose:');
      for (final e in byPurpose.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
        lines.add('  ${e.key}: ${e.value} requests');
      }
    }

    return lines.join('\n');
  }
}
