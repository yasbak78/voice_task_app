import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum RecordingState { idle, recording, processing, done, error }

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
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
    
    if (!await _checkPermission()) {
      _state = RecordingState.error;
      throw Exception('Microphone permission denied');
    }

    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );

      _state = RecordingState.recording;
      _duration = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _duration += const Duration(seconds: 1);
      });
    } else {
      _state = RecordingState.error;
      throw Exception('No microphone permission');
    }
  }

  Future<String?> stopRecording() async {
    if (_state != RecordingState.recording) return null;
    
    _timer?.cancel();
    _state = RecordingState.processing;
    
    final path = await _recorder.stop();
    if (path != null) {
      _lastRecordingPath = path;
    }
    _state = path != null ? RecordingState.done : RecordingState.error;
    return path;
  }

  Future<void> cancel() async {
    _timer?.cancel();
    if (_state == RecordingState.recording) {
      await _recorder.stop();
    }
    _state = RecordingState.idle;
    _duration = Duration.zero;
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
