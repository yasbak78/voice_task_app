import 'dart:async';
import 'dart:developer' as dev;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum RecordingState { idle, recording, processing, done, error }

class AudioRecorderService {
  AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _lastRecordingPath;

  RecordingState get state => _state;
  Duration get duration => _duration;
  String? get lastRecordingPath => _lastRecordingPath;
  Stream<Amplitude> get amplitudeStream => _recorder.onAmplitudeChanged(const Duration(milliseconds: 250));

  Future<bool> _checkPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording() async {
    if (_state == RecordingState.recording) return;
    
    dev.log('[AudioRecorder] Starting recording, current state: $_state');
    
    if (!await _checkPermission()) {
      dev.log('[AudioRecorder] Microphone permission denied');
      _state = RecordingState.error;
      throw Exception('Microphone permission denied');
    }

    dev.log('[AudioRecorder] Permission granted, checking recorder.hasPermission()');
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      dev.log('[AudioRecorder] Recording to: $path');
      
      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
            bitRate: 256000,
          ),
          path: path,
        );
        dev.log('[AudioRecorder] Recorder.start() succeeded');

        _state = RecordingState.recording;
        _duration = Duration.zero;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          _duration += const Duration(seconds: 1);
        });
      } catch (e, st) {
        dev.log('[AudioRecorder] Recorder.start() failed: $e\n$st');
        _state = RecordingState.error;
        throw Exception('Failed to start recording: $e');
      }
    } else {
      dev.log('[AudioRecorder] Recorder.hasPermission() returned false');
      _state = RecordingState.error;
      throw Exception('No microphone permission');
    }
  }

  Future<String?> stopRecording() async {
    if (_state != RecordingState.recording) return null;
    
    _timer?.cancel();
    _state = RecordingState.processing;
    
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      dev.log('[AudioRecorder] stop() failed: $e\n$st');
      _state = RecordingState.error;
      return null;
    }
    
    // FIX: Dispose and recreate the native AudioRecorder after each stop.
    // On Android, the native AudioRecord session is not properly reset after
    // stop(), causing subsequent start() calls to fail silently. Disposing
    // and recreating ensures a fresh native audio session for each recording.
    try {
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
    
    if (path != null) {
      _lastRecordingPath = path;
    }
    _state = path != null ? RecordingState.done : RecordingState.error;
    return path;
  }

  Future<void> cancel() async {
    _timer?.cancel();
    if (_state == RecordingState.recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    try {
      await _recorder.dispose();
    } catch (_) {}
    _recorder = AudioRecorder();
    _state = RecordingState.idle;
    _duration = Duration.zero;
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
