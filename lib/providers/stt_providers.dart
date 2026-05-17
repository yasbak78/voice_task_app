import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/stt/audio_recorder.dart';
import '../core/stt/whisper_service.dart';

/// Provider for the audio recorder service singleton.
final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

/// Provider for the whisper service singleton.
final whisperServiceProvider = Provider<WhisperService>((ref) {
  final service = WhisperService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider exposing the current recording state.
final recordingStateProvider = Provider<RecordingState>((ref) {
  final recorder = ref.watch(audioRecorderProvider);
  return recorder.state;
});

/// Provider exposing the current recording duration.
final recordingDurationProvider = Provider<Duration>((ref) {
  final recorder = ref.watch(audioRecorderProvider);
  return recorder.duration;
});

/// Provider for running transcription on the last recording.
final transcriptionProvider = FutureProvider.autoDispose<String?>((ref) async {
  final recorder = ref.watch(audioRecorderProvider);
  final lastPath = recorder.lastRecordingPath;
  
  if (lastPath == null) return null;
  
  final service = ref.watch(whisperServiceProvider);
  return service.transcribe(lastPath);
});
