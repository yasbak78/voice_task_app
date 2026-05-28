/// AI provider configuration for the Voice Task App.
///
/// Supports multiple free-tier LLM providers. Switch the active provider
/// by changing [currentProvider]. All providers use OpenAI-compatible
/// `/v1/chat/completions` endpoints.
enum AIProvider { groq, openrouter, deepseek, gemini }

class AIConfig {
  AIConfig._();

  /// Active provider — change this to switch LLM backends.
  static AIProvider currentProvider = AIProvider.groq;

  /// Ordered list of providers for automatic fallback.
  /// If the current provider fails (429/timeout/network), the client
  /// tries the next one in this list.
  static const fallbackOrder = [
    AIProvider.groq,
    AIProvider.openrouter,
    AIProvider.deepseek,
  ];

  /// HTTP timeout for AI requests.
  static const requestTimeout = Duration(seconds: 15);

  /// Max tokens for task parsing (compact JSON output).
  static const int maxParseTokens = 250;

  /// Max tokens for scheduling suggestions.
  static const int maxSchedulingTokens = 512;

  /// Max tokens for general chat/health checks.
  static const int maxChatTokens = 100;

  /// Legacy: used as default when no purpose-specific limit set.
  static int get maxTokens => maxParseTokens;

  /// Temperature for task parsing (deterministic = 0).
  static const double parseTemperature = 0.0;

  /// Temperature for conversational responses (creative = 0.7).
  static const double chatTemperature = 0.7;

  // ─── Provider Configurations ───────────────────────────────────────────

  static const Map<AIProvider, ProviderConfig> _configs = {
    AIProvider.groq: ProviderConfig(
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKey: 'gsk_oY...j042',
      model: 'llama-3.3-70b-versatile',
      label: 'Groq (Llama 3.3 70B)',
      dailyTokenBudget: 200_000,
    ),
    AIProvider.openrouter: ProviderConfig(
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: 'sk-or-...b0ee',
      model: 'meta-llama/llama-3.3-70b-instruct',
      label: 'OpenRouter (Llama 3.3 70B)',
      dailyTokenBudget: 30_000,
    ),
    AIProvider.deepseek: ProviderConfig(
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'sk-366...aad1',
      model: 'deepseek-chat',
      label: 'DeepSeek V3',
      dailyTokenBudget: 50_000,
    ),
    AIProvider.gemini: ProviderConfig(
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      apiKey: 'YOUR_GEMINI_API_KEY', // ← Add your key here
      model: 'gemini-2.5-flash',
      label: 'Google Gemini 2.5 Flash',
      dailyTokenBudget: 0, // free, no hard limit
    ),
  };

  static ProviderConfig get current => _configs[currentProvider]!;

  static String get completionsUrl => '${current.baseUrl}/chat/completions';

  static String get activeLabel => current.label;

  /// Access all provider configs by label (used in settings UI).
  static ProviderConfig? configByLabel(String label) =>
      _configs.values.firstWhere(
        (c) => c.label == label,
        orElse: () => _configs.values.first,
      );

  /// Get config for a specific provider (used in fallback chain).
  static ProviderConfig? configFor(AIProvider provider) => _configs[provider];

  /// All configured providers with non-placeholder keys.
  static Iterable<AIProvider> get availableProviders =>
      _configs.entries
          .where((e) => !e.value.apiKey.startsWith('YOUR_'))
          .map((e) => e.key);
}

class ProviderConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final String label;
  /// Daily token budget for free-tier monitoring (0 = unlimited / not tracked).
  final int dailyTokenBudget;

  const ProviderConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.label,
    this.dailyTokenBudget = 0,
  });

  String get completionsUrl => '$baseUrl/chat/completions';

  /// How much of today's budget is used (0.0–1.0). Returns null if no budget set.
  double? budgetUsageFraction(int tokensUsedToday) {
    if (dailyTokenBudget <= 0) return null;
    return (tokensUsedToday / dailyTokenBudget).clamp(0.0, 1.0);
  }
}
