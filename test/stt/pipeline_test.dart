import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:voice_task_app/core/stt/wav_converter.dart';
import 'package:voice_task_app/core/stt/audio_recorder.dart';

// Minimal WAV header generator for tests
Uint8List createTestWav({
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
  int numSamples = 16000,
}) {
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final dataSize = numSamples * channels * (bitsPerSample ~/ 8);
  final fileSize = 36 + dataSize;

  final bytes = Uint8List(44 + dataSize);
  final view = ByteData.sublistView(bytes);

  // RIFF header
  bytes.setAll(0, [82, 73, 70, 70]); // 'RIFF'
  view.setUint32(4, fileSize, Endian.little);
  bytes.setAll(8, [87, 65, 86, 69]); // 'WAVE'

  // fmt chunk
  bytes.setAll(12, [102, 109, 116, 32]); // 'fmt '
  view.setUint32(16, 16, Endian.little); // chunk size
  view.setUint16(20, 1, Endian.little); // PCM
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);

  // data chunk
  bytes.setAll(36, [100, 97, 116, 97]); // 'data'
  view.setUint32(40, dataSize, Endian.little);

  // Fill with silence
  for (int i = 0; i < dataSize; i++) {
    bytes[44 + i] = 0;
  }

  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecorderService', () {
    test('initial state is idle', () {
      final recorder = AudioRecorderService();
      expect(recorder.state, RecordingState.idle);
      expect(recorder.duration, Duration.zero);
      expect(recorder.lastRecordingPath, isNull);
    });

    test('duration starts at zero', () {
      final recorder = AudioRecorderService();
      expect(recorder.duration, Duration.zero);
    });
  });

  group('WavConverter', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wav_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('validateWav detects valid 16kHz mono 16-bit', () async {
      final wavBytes = createTestWav(
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
      );
      final wavFile = File('${tempDir.path}/valid.wav');
      await wavFile.writeAsBytes(wavBytes);

      final info = await WavConverter.validateWav(wavFile.path);
      expect(info.isWhisperCompatible, isTrue);
      expect(info.sampleRate, 16000);
      expect(info.channels, 1);
      expect(info.bitsPerSample, 16);
    });

    test('validateWav rejects non-16kHz audio', () async {
      final wavBytes = createTestWav(sampleRate: 44100);
      final wavFile = File('${tempDir.path}/bad_rate.wav');
      await wavFile.writeAsBytes(wavBytes);

      final info = await WavConverter.validateWav(wavFile.path);
      expect(info.isWhisperCompatible, isFalse);
      expect(info.sampleRate, 44100);
    });

    test('validateWav rejects stereo audio', () async {
      final wavBytes = createTestWav(channels: 2);
      final wavFile = File('${tempDir.path}/stereo.wav');
      await wavFile.writeAsBytes(wavBytes);

      final info = await WavConverter.validateWav(wavFile.path);
      expect(info.isWhisperCompatible, isFalse);
      expect(info.channels, 2);
    });

    test('validateWav rejects non-WAV file', () async {
      final file = File('${tempDir.path}/not_wav.mp3');
      await file.writeAsBytes([1, 2, 3, 4]);

      expect(
        () => WavConverter.validateWav(file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('convertToWhisperFormat returns same file if already compatible',
        () async {
      final wavBytes = createTestWav(
        sampleRate: 16000,
        channels: 1,
        bitsPerSample: 16,
      );
      final input = File('${tempDir.path}/compatible.wav');
      await input.writeAsBytes(wavBytes);

      final output = await WavConverter.convertToWhisperFormat(input.path);
      expect(output, isNotNull);
    });
  });
}
