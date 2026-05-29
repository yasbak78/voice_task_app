import 'package:flutter/services.dart';

/// Platform channel service for notification sounds and chimes.
/// Handles: sound preview, completion chimes, system sound fallback.
class SoundPreviewService {
  static const _channel = MethodChannel('voice_task_app/sound_preview');
  static String? _currentlyPlaying;

  /// Play a sound preview. Stops any currently playing preview first.
  /// [sound] should match the Android resource name (e.g. 'gentle_ping').
  static Future<void> play(String sound) async {
    if (_currentlyPlaying != null) {
      await stop();
    }
    _currentlyPlaying = sound;
    try {
      await _channel.invokeMethod('playPreview', {'sound': sound});
    } catch (e) {
      _currentlyPlaying = null;
      rethrow;
    }
  }

  /// Stop the currently playing sound preview.
  static Future<void> stop() async {
    if (_currentlyPlaying == null) return;
    try {
      await _channel.invokeMethod('stopPreview');
    } finally {
      _currentlyPlaying = null;
    }
  }

  /// Play a completion chime sound.
  /// Available: 'completion_chime' (3-note ascending),
  /// 'success_ping' (quick single tone),
  /// 'gentle_complete' (soft two-note).
  static Future<void> playChime({String sound = 'completion_chime'}) async {
    try {
      await _channel.invokeMethod('playChime', {'sound': sound});
    } catch (e) {
      // Silently fail — chime is non-critical feedback
    }
  }

  /// Play the system default notification sound.
  /// Used as fallback when no custom sound is configured.
  static Future<void> playSystemSound() async {
    try {
      await _channel.invokeMethod('playSystemNotificationSound');
    } catch (e) {
      // Silently fail — system sound is non-critical feedback
    }
  }

  /// Returns true if a sound is currently playing.
  static bool get isPlaying => _currentlyPlaying != null;

  /// Returns the name of the currently playing sound, or null.
  static String? get currentlyPlaying => _currentlyPlaying;
}
