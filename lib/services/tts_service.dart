import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_tts/flutter_tts.dart';
import '../config/tts_config.dart';

/// TTS engine states.
enum TtsState { idle, speaking, paused, stopped, error }

/// Result of a TTS speak operation.
class TtsResult {
  final bool success;
  final String? error;
  final TtsProvider usedProvider;
  final Duration? duration;

  const TtsResult({
    required this.success,
    this.error,
    required this.usedProvider,
    this.duration,
  });

  @override
  String toString() =>
      'TtsResult(success: $success, provider: ${usedProvider.name}${error != null ? ", error: $error" : ""})';
}

/// High-level TTS service wrapping flutter_tts with configuration management.
///
/// Usage:
///   final tts = TtsService();
///   await tts.speak('Task saved successfully');
///   await tts.stop();
class TtsService {
  FlutterTts? _flutterTts;
  TtsState _state = TtsState.idle;
  bool _initialized = false;
  final _stateController = StreamController<TtsState>.broadcast();

  TtsState get state => _state;
  Stream<TtsState> get stateStream => _stateController.stream;

  /// Initialize the TTS engine and apply configuration.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _flutterTts = FlutterTts();

      // Set up handlers
      _flutterTts!.setCompletionHandler(() {
        _setState(TtsState.stopped);
      });

      _flutterTts!.setErrorHandler((msg) {
        dev.log('[TTS] Error: $msg');
        _setState(TtsState.error);
      });

      _flutterTts!.setStartHandler(() {
        _setState(TtsState.speaking);
      });

      // Apply configuration
      await _flutterTts!.setSpeechRate(TtsConfig.speechRate);
      await _flutterTts!.setPitch(TtsConfig.pitch);
      await _flutterTts!.setVolume(TtsConfig.volume);
      await _flutterTts!.setLanguage(TtsConfig.locale);

      _initialized = true;
      dev.log('[TTS] Initialized: ${TtsConfig.activeLabel}');
      return true;
    } catch (e) {
      dev.log('[TTS] Initialization failed: $e');
      _flutterTts = null;
      return false;
    }
  }

  /// Speak text using the configured TTS provider.
  /// Auto-initializes if not already initialized.
  Future<TtsResult> speak(String text) async {
    if (text.trim().isEmpty) {
      return TtsResult(
        success: false,
        error: 'Empty text',
        usedProvider: TtsConfig.currentProvider,
      );
    }

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        return TtsResult(
          success: false,
          error: 'TTS engine failed to initialize',
          usedProvider: TtsConfig.currentProvider,
        );
      }
    }

    final start = DateTime.now();
    try {
      await _flutterTts!.speak(text);
      return TtsResult(
        success: true,
        usedProvider: TtsConfig.currentProvider,
        duration: DateTime.now().difference(start),
      );
    } catch (e) {
      dev.log('[TTS] Speak failed: $e');
      _setState(TtsState.error);
      return TtsResult(
        success: false,
        error: e.toString(),
        usedProvider: TtsConfig.currentProvider,
      );
    }
  }

  /// Stop current speech.
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _setState(TtsState.stopped);
    }
  }

  /// Pause current speech.
  Future<void> pause() async {
    if (_flutterTts != null) {
      await _flutterTts!.pause();
      _setState(TtsState.paused);
    }
  }

  /// Check if TTS is available and working.
  Future<bool> isAvailable() async {
    if (!_initialized) {
      return initialize();
    }
    return _flutterTts != null;
  }

  /// Update speech rate and apply to engine.
  Future<void> setRate(double rate) async {
    TtsConfig.speechRate = rate.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(TtsConfig.speechRate);
    }
  }

  /// Update pitch and apply to engine.
  Future<void> setPitch(double pitch) async {
    TtsConfig.pitch = pitch.clamp(0.0, 2.0);
    if (_flutterTts != null) {
      await _flutterTts!.setPitch(TtsConfig.pitch);
    }
  }

  /// Update volume and apply to engine.
  Future<void> setVolume(double volume) async {
    TtsConfig.volume = volume.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setVolume(TtsConfig.volume);
    }
  }

  /// Get list of available voices on the device.
  Future<List<dynamic>> getVoices() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return [];
    }
    try {
      return await _flutterTts!.getVoices;
    } catch (e) {
      dev.log('[TTS] getVoices failed: $e');
      return [];
    }
  }

  /// Get list of available languages.
  Future<List<dynamic>> getLanguages() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return [];
    }
    try {
      return await _flutterTts!.getLanguages;
    } catch (e) {
      dev.log('[TTS] getLanguages failed: $e');
      return [];
    }
  }

  void _setState(TtsState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Dispose the TTS engine and release resources.
  Future<void> dispose() async {
    await _flutterTts?.stop();
    await _stateController.close();
    _flutterTts = null;
    _initialized = false;
    _state = TtsState.idle;
  }
}

/// Global singleton instance for app-wide use.
final ttsService = TtsService();
