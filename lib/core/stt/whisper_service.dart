import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'whisper_ffi.dart';
import 'whisper_model_manager.dart';
import 'wav_converter.dart';

/// Sampling strategy constants from whisper.h
enum WhisperSamplingStrategy {
  greedy(0),
  beamSearch(1);

  final int value;
  const WhisperSamplingStrategy(this.value);
}

/// High-level STT service combining FFI, model management, and audio conversion.
class WhisperService {
  final WhisperModelManager _modelManager = WhisperModelManager();
  bool _isInitialized = false;
  Pointer<Void>? _context;

  bool get isInitialized => _isInitialized;

  /// Initializes the whisper service by loading the model.
  Future<void> initialize({
    void Function(double progress)? onModelDownloadProgress,
  }) async {
    if (_isInitialized) return;

    final modelPath = await _modelManager.getModelPath(
      onProgress: onModelDownloadProgress,
    );

    try {
      final ffi = WhisperFFI.instance;

      // Get default context params (GPU disabled for Android stability)
      final cParamsPtr = ffi.whisperContextDefaultParamsByRef();
      final cParams = cParamsPtr.ref;
      cParams.useGpu = false; // CPU-only for now, avoids Android GPU driver issues

      final modelPtr = modelPath.toNativeUtf8();
      _context = ffi.whisperInitFromFileWithParams(modelPtr, cParams);
      calloc.free(modelPtr);
      ffi.whisperFreeContextParams(cParamsPtr);

      if (_context == null || _context!.address == 0) {
        throw Exception('Failed to initialize whisper context (returned NULL)');
      }

      _isInitialized = true;
    } catch (e) {
      throw Exception('Whisper initialization failed: $e');
    }
  }

  /// Transcribes an audio file to text.
  Future<String> transcribe(String audioPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    final convertedPath = await WavConverter.convertToWhisperFormat(audioPath);
    final wavInfo = await WavConverter.validateWav(convertedPath);

    if (!wavInfo.isWhisperCompatible) {
      throw Exception(
        'Audio not in whisper.cpp format: ${wavInfo.sampleRate}Hz, '
        '${wavInfo.channels}ch, ${wavInfo.bitsPerSample}bit',
      );
    }

    return _transcribeWav(convertedPath);
  }

  String _transcribeWav(String wavPath) {
    final ffi = WhisperFFI.instance;
    final wavFile = File(wavPath);
    final bytes = wavFile.readAsBytesSync();

    // Skip WAV header (44 bytes) to get raw PCM data
    if (bytes.length < 44) {
      throw Exception('Invalid WAV file: too small (${bytes.length} bytes)');
    }

    final pcmData = bytes.sublist(44);
    final numSamples = pcmData.length ~/ 2; // 16-bit = 2 bytes per sample

    if (numSamples == 0) {
      return '[Silent audio]';
    }

    // Convert 16-bit PCM to float32 samples (whisper.cpp expects float [-1.0, 1.0])
    final samples = calloc<Float>(numSamples);
    final byteData = ByteData.sublistView(pcmData);

    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      samples[i] = sample / 32768.0;
    }

    Pointer<WhisperFullParams> paramsPtr = calloc();
    try {
      // Get default params by ref (pointer, not struct-by-value)
      paramsPtr = ffi.whisperFullDefaultParamsByRef(WhisperSamplingStrategy.greedy.value);

      // Configure for Android
      paramsPtr.ref.nThreads = 2;
      paramsPtr.ref.noTimestamps = true;
      paramsPtr.ref.printProgress = false;
      paramsPtr.ref.printSpecial = false;
      paramsPtr.ref.printRealtime = false;
      paramsPtr.ref.printTimestamps = false;
      paramsPtr.ref.language = 'en'.toNativeUtf8();
      paramsPtr.ref.detectLanguage = false;

      final result = ffi.whisperFull(
        _context!,
        paramsPtr,
        samples,
        numSamples,
      );

      if (result != 0) {
        throw Exception('whisper_full failed with code: $result');
      }

      // Extract transcribed text from segments
      final buffer = StringBuffer();
      final nSegments = ffi.whisperFullNSegments(_context!);

      for (int i = 0; i < nSegments; i++) {
        final textPtr = ffi.whisperFullGetSegmentText(_context!, i);
        if (textPtr.address == 0) continue;

        final text = textPtr.toDartString();
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      }

      final transcript = buffer.toString().trim();
      return transcript.isEmpty ? '[No speech detected]' : transcript;
    } finally {
      calloc.free(samples);
      ffi.whisperFreeParams(paramsPtr);
    }
  }

  /// Releases whisper resources.
  void dispose() {
    if (_context != null && _context!.address != 0) {
      try {
        final ffi = WhisperFFI.instance;
        ffi.whisperFree(_context!);
      } catch (_) {}
      _context = null;
    }
    _isInitialized = false;
  }
}
