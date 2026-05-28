/// Token usage from a single API request.
class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final DateTime timestamp;
  final String provider;
  final String model;
  final String purpose; // e.g., 'task_parse', 'nl_query', 'scheduling', 'health_check'

  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.timestamp,
    required this.provider,
    required this.model,
    required this.purpose,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        promptTokens: json['prompt_tokens'] as int? ?? 0,
        completionTokens: json['completion_tokens'] as int? ?? 0,
        totalTokens: json['total_tokens'] as int? ?? 0,
        timestamp:
            DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
        provider: json['provider'] as String? ?? 'unknown',
        model: json['model'] as String? ?? 'unknown',
        purpose: json['purpose'] as String? ?? 'unknown',
      );

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        'timestamp': timestamp.toIso8601String(),
        'provider': provider,
        'model': model,
        'purpose': purpose,
      };

  @override
  String toString() =>
      '$provider: $totalTokens tokens (prompt: $promptTokens, completion: $completionTokens)';
}
