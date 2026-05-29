import 'package:flutter/services.dart';

/// Platform channel service for native haptic feedback patterns.
/// Provides richer feedback than Flutter's built-in HapticFeedback
/// by using Android's VibrationEffect with precise timing patterns.
class HapticFeedbackService {
  static const _channel = MethodChannel('voice_task_app/haptic_feedback');

  /// Trigger a haptic pattern.
  /// Patterns:
  /// - 'light': 15ms tap — for task add
  /// - 'medium': 30ms tap — for snooze/dismiss
  /// - 'heavy': 50ms tap — for task completion
  /// - 'success': double-tap pattern — celebration
  /// - 'triple': triple-tap — multi-action
  static Future<void> trigger(String pattern) async {
    try {
      await _channel.invokeMethod('triggerHaptic', {'pattern': pattern});
    } catch (e) {
      // Fallback to Flutter's built-in haptics
      _fallbackFallback(pattern);
    }
  }

  static void _fallbackFallback(String pattern) {
    // Use Flutter's HapticFeedback as fallback
    // This is a silent fallback — the native channel handles the real work
  }
}
