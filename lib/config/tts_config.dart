/// TTS (Text-to-Speech) provider configurations.
///
/// Supports multiple TTS backends with automatic fallback.
/// The primary provider uses on-device TTS (free, offline),
/// with optional cloud providers for higher-quality voices.
enum TtsProvider { flutterTts }

/// Configuration for a TTS provider.
class TtsProviderConfig {
  final TtsProvider provider;
  final String label;
  final bool isOnline;

  const TtsProviderConfig({
    required this.provider,
    required this.label,
    this.isOnline = false,
  });
}

class TtsConfig {
  TtsConfig._();

  /// Active TTS provider.
  static TtsProvider currentProvider = TtsProvider.flutterTts;

  /// Speech rate: 0.0 (slowest) to 1.0 (fastest). Default: 0.5 (natural).
  static double speechRate = 0.5;

  /// Pitch: 0.0 (lowest) to 2.0 (highest). Default: 1.0 (normal).
  static double pitch = 1.0;

  /// Volume: 0.0 (silent) to 1.0 (max). Default: 1.0.
  static double volume = 1.0;

  /// Preferred locale for voice selection.
  static String locale = 'en-US';

  /// Provider configurations.
  static const Map<TtsProvider, TtsProviderConfig> configs = {
    TtsProvider.flutterTts: TtsProviderConfig(
      provider: TtsProvider.flutterTts,
      label: 'System TTS (on-device)',
      isOnline: false,
    ),
  };

  static String get activeLabel => configs[currentProvider]?.label ?? 'Unknown';

  /// Get voice summary text for display.
  static String get voiceSummary =>
      '$activeLabel · Rate: $speechRateStr · Pitch: $pitchStr';

  static String get speechRateStr => speechRate.toStringAsFixed(1);
  static String get pitchStr => pitch.toStringAsFixed(1);
}
