import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/token_usage.dart';
import '../services/token_tracker.dart';

/// Error indicating all providers are over daily budget.
class BudgetExhaustedError extends Error {
  @override
  String toString() => 'BudgetExhaustedError: All providers exceeded daily token quota';
}

/// Error indicating the AI provider rate-limited the request.
class RateLimitError extends Error {
  final AIProvider provider;
  final int retryAfterSeconds;
  RateLimitError(this.provider, [this.retryAfterSeconds = 60]);

  @override
  String toString() =>
      'RateLimitError: ${provider.name} rate limited (retry after ${retryAfterSeconds}s)';
}

/// Error indicating all providers in the fallback chain failed.
class AllProvidersExhaustedError extends Error {
  final List<String> errors;
  AllProvidersExhaustedError(this.errors);

  @override
  String toString() =>
      'AllProvidersExhaustedError: ${errors.join("; ")}';
}

/// Lightweight HTTP client for OpenAI-compatible LLM APIs.
///
/// Supports automatic fallback across multiple free-tier providers.
/// Usage:
///   final response = await AIClient.chat(
///     messages: [...],
///     temperature: 0.0,
///   );
class AIClient {
  AIClient._();

  /// Send a chat completion request with automatic provider fallback.
  ///
  /// Tries the current provider first, then falls back through
  /// [AIConfig.fallbackOrder] on 429 (rate limit) or network errors.
  ///
  /// Returns the raw `content` string from the first `assistant` message.
  ///
  /// The [purpose] parameter categorizes the request for usage tracking
  /// (e.g., 'task_parse', 'nl_query', 'scheduling', 'health_check').
  ///
  /// When [jsonMode] is true, forces JSON-only responses via
  /// `response_format: { type: "json_object" }` — reduces token waste
  /// from conversational filler.
  static Future<String> chat({
    required List<Map<String, String>> messages,
    double temperature = 0.0,
    int? maxTokens,
    String purpose = 'unknown',
    bool jsonMode = false,
  }) async {
    final providersToTry = _buildFallbackChain();
    final errors = <String>[];
    var allOverBudget = true;

    for (final provider in providersToTry) {
      final config = AIConfig.configFor(provider);
      if (config == null) continue;

      // Check daily budget — skip providers over limit
      if (await _isOverBudget(config)) {
        errors.add('${provider.name}: daily budget exceeded');
        continue;
      }
      allOverBudget = false;

      try {
        return await _tryProvider(
          config: config,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens ?? AIConfig.maxTokens,
          purpose: purpose,
          jsonMode: jsonMode,
        );
      } on RateLimitError catch (e) {
        errors.add('${provider.name}: rate limited (${e.retryAfterSeconds}s)');
      } on TimeoutException {
        errors.add('${provider.name}: timed out (${AIConfig.requestTimeout})');
      } on http.ClientException catch (e) {
        errors.add('${provider.name}: network error (${e.message})');
      } catch (e) {
        errors.add('${provider.name}: ${e.toString().substring(0, 100)}');
      }
    }

    if (allOverBudget) {
      throw BudgetExhaustedError();
    }
    throw AllProvidersExhaustedError(errors);
  }

  /// Check if a provider has exceeded its daily token budget.
  /// Returns true if budget is set and >90% consumed (early cutoff to save fallback room).
  static Future<bool> _isOverBudget(ProviderConfig config) async {
    if (config.dailyTokenBudget <= 0) return false; // unlimited
    final todayUsage = await TokenTracker.getTodayTotalTokens(config.label);
    return todayUsage >= config.dailyTokenBudget * 0.9;
  }

  /// Build the ordered list of providers to attempt.
  static List<AIProvider> _buildFallbackChain() {
    final chain = <AIProvider>{};

    // Start with the current provider
    chain.add(AIConfig.currentProvider);

    // Then add fallback providers in order (skip the current one if already added)
    for (final p in AIConfig.fallbackOrder) {
      if (p != AIConfig.currentProvider) {
        chain.add(p);
      }
    }

    // Also try any other available providers not yet in the chain
    for (final p in AIConfig.availableProviders) {
      if (!chain.contains(p)) {
        chain.add(p);
      }
    }

    return chain.toList();
  }

  /// Attempt a single provider. Throws on failure (caught by caller).
  static Future<String> _tryProvider({
    required ProviderConfig config,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxTokens,
    String purpose = 'unknown',
    bool jsonMode = false,
  }) async {
    final bodyMap = <String, dynamic>{
      'model': config.model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    if (jsonMode) {
      bodyMap['response_format'] = {'type': 'json_object'};
    }
    final body = jsonEncode(bodyMap);

    final response = await http
        .post(
          Uri.parse(config.completionsUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: body,
        )
        .timeout(AIConfig.requestTimeout);

    if (response.statusCode == 429) {
      // Parse Retry-After header if present
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '60') ?? 60;
      throw RateLimitError(AIConfig.currentProvider, retryAfter);
    }

    if (response.statusCode != 200) {
      throw Exception(
        'API error ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;

    if (choices == null || choices.isEmpty) {
      throw Exception('Empty response from ${config.label}');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('Empty content from ${config.label}');
    }

    // Extract and record token usage from response
    final usage = data['usage'] as Map<String, dynamic>?;
    if (usage != null) {
      final tokenUsage = TokenUsage(
        promptTokens: usage['prompt_tokens'] as int? ?? 0,
        completionTokens: usage['completion_tokens'] as int? ?? 0,
        totalTokens: usage['total_tokens'] as int? ?? 0,
        timestamp: DateTime.now(),
        provider: config.label,
        model: config.model,
        purpose: purpose,
      );
      // Fire-and-forget recording — don't block the response
      TokenTracker.record(tokenUsage).catchError((_) {/* silently ignore */});
    }

    return content;
  }

  /// Quick health check — tests if the current provider is reachable.
  /// Returns (success, providerLabel, error).
  static Future<(bool, String, String?)> healthCheck() async {
    final config = AIConfig.current;
    try {
      await _tryProvider(
        config: config,
        messages: [
          {'role': 'user', 'content': 'Say "ok" and nothing else'},
        ],
        temperature: 0.0,
        maxTokens: 10,
        purpose: 'health_check',
      ).timeout(AIConfig.requestTimeout);
      return (true, config.label, null);
    } on TimeoutException {
      return (false, config.label, 'Connection timed out after ${AIConfig.requestTimeout.inSeconds}s');
    } catch (e) {
      final msg = e.toString();
      return (false, config.label, msg.substring(0, msg.length.clamp(0, 150)));
    }
  }
}
