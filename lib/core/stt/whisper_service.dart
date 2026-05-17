import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'whisper_ffi.dart';
import 'whisper_model_manager.dart';
import 'wav_converter.dart';

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
      final modelPtr = modelPath.toNativeUtf8();
      _context = ffi.whisperInitFromFile(modelPtr);
      calloc.free(modelPtr);

      if (_context == null || _context!.address == 0) {
        throw Exception('Failed to initialize whisper context');
      }

      _isInitialized = true;
    } catch (e) {
      throw Exception('Whisper initialization failed: $e');
    }
  }

  /// Transcribes an audio file to text.
  /// 
  /// [audioPath] — path to the audio file (any format supported by record package)
  /// Returns the transcribed text string.
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
      throw Exception('Invalid WAV file: too small');
    }
    
    final pcmData = bytes.sublist(44);
    final numSamples = pcmData.length ~/ 2; // 16-bit = 2 bytes per sample
    
    // Convert 16-bit PCM to float32 samples (whisper.cpp expects float samples)
    final samples = calloc<Float>(numSamples);
    final byteData = ByteData.sublistView(pcmData);
    
    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      samples[i] = sample / 32768.0; // Normalize to [-1.0, 1.0]
    }

    try {
      final params = calloc<WhisperFullParams>();
      final defaultParams = ffi.whisperFullDefaultParams();
      params.ref = defaultParams;
      
      // Set common parameters
      params.ref.nThreads = 4;
      
      final result = ffi.whisperFull(
        _context!,
        params,
        samples,
        numSamples,
      );
      
      calloc.free(params);
      
      if (result != 0) {
        throw Exception('whisper_full failed with code: $result');
      }

      // Extract transcribed text from segments
      final buffer = StringBuffer();
      var segmentIndex = 0;
      
      while (true) {
        final textPtr = ffi.whisperGetText(_context!, segmentIndex);
        if (textPtr.address == 0) break;
        
        final text = textPtr.toDartString();
        if (text.isEmpty) break;
        
        buffer.write(text);
        segmentIndex++;
      }

      final transcript = buffer.toString().trim();
      
      if (transcript.isEmpty) {
        return '[No speech detected]';
      }
      
      return transcript;
    } finally {
      calloc.free(samples);
    }
  }

  /// Releases whisper resources.
  void dispose() {
    if (_context != null && _context!.address != 0) {
      try {
        final ffi = WhisperFFI.instance;
        ffi.whisperFree(_context!);
      } catch (_) {
        // Ignore cleanup errors
      }
      _context = null;
    }
    _isInitialized = false;
  }
}
