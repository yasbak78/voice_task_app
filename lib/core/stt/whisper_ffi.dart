import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// FFI type definitions for whisper.cpp
typedef WhisperInitFromFile = Pointer<Void> Function(Pointer<Utf8> path);
typedef WhisperInitFromFileDart = Pointer<Void> Function(Pointer<Utf8> path);

typedef WhisperFull = Int32 Function(
  Pointer<Void> ctx,
  Pointer<WhisperFullParams> params,
  Pointer<Float> samples,
  Int32 nSamples,
);
typedef WhisperFullDart = int Function(
  Pointer<Void> ctx,
  Pointer<WhisperFullParams> params,
  Pointer<Float> samples,
  int nSamples,
);

typedef WhisperGetText = Pointer<Utf8> Function(
  Pointer<Void> ctx,
  Int32 nSegment,
);
typedef WhisperGetTextDart = Pointer<Utf8> Function(
  Pointer<Void> ctx,
  int nSegment,
);

typedef WhisperFree = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

typedef WhisperNCtx = Int32 Function();
typedef WhisperNCtxDart = int Function();

typedef WhisperFullDefaultParams = WhisperFullParams Function();
typedef WhisperFullDefaultParamsDart = WhisperFullParams Function();

/// FFI bindings to whisper.cpp shared library.
/// 
/// Expects `libwhisper.so` (Linux/Android) or `libwhisper.dylib` (macOS)
/// in the appropriate platform directory.
/// 
/// Build instructions: see `native/whisper/README.md`
class WhisperFFI {
  static WhisperFFI? _instance;
  late final DynamicLibrary _lib;
  
  late final WhisperInitFromFileDart whisperInitFromFile;
  late final WhisperFullDart whisperFull;
  late final WhisperGetTextDart whisperGetText;
  late final WhisperFreeDart whisperFree;
  late final WhisperNCtxDart whisperNCtx;
  late final WhisperFullDefaultParamsDart whisperFullDefaultParams;

  WhisperFFI._();

  /// Returns the singleton instance, loading the native library.
  static WhisperFFI get instance {
    _instance ??= WhisperFFI._().._loadLibrary();
    return _instance!;
  }

  void _loadLibrary() {
    String libPath;
    if (Platform.isLinux || Platform.isAndroid) {
      libPath = 'libwhisper.so';
    } else if (Platform.isMacOS) {
      libPath = 'libwhisper.dylib';
    } else if (Platform.isWindows) {
      libPath = 'whisper.dll';
    } else {
      throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
    }

    try {
      _lib = DynamicLibrary.open(libPath);
    } on ArgumentError catch (e) {
      throw UnsupportedError(
        'Failed to load whisper library ($libPath): $e\n'
        'Build whisper.cpp and place $libPath in the app directory.',
      );
    }

    whisperInitFromFile = _lib
        .lookupFunction<WhisperInitFromFile, WhisperInitFromFileDart>('whisper_init_from_file_with_state');
    
    whisperFull = _lib
        .lookupFunction<WhisperFull, WhisperFullDart>('whisper_full');
    
    whisperGetText = _lib
        .lookupFunction<WhisperGetText, WhisperGetTextDart>('whisper_full_get_segment_text');
    
    whisperFree = _lib
        .lookupFunction<WhisperFree, WhisperFreeDart>('whisper_free');
    
    whisperNCtx = _lib
        .lookupFunction<WhisperNCtx, WhisperNCtxDart>('whisper_model_n_vocab');
    
    whisperFullDefaultParams = _lib
        .lookupFunction<WhisperFullDefaultParams, WhisperFullDefaultParamsDart>(
          'whisper_full_default_params',
        );
  }

  /// Checks if the native library is available.
  static bool get isAvailable {
    try {
      instance;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Whisper full parameters struct — matches whisper.cpp `whisper_full_params`.
/// 
/// Must be kept in sync with whisper.cpp struct layout.
/// Reference: https://github.com/ggerganov/whisper.cpp/blob/master/include/whisper.h
base class WhisperFullParams extends Struct {
  @Int32()
  external int strategy;         // whisper_sampling_strategy

  @Int32()
  external int nThreads;

  @Int32()
  external int nMaxTextCtx;

  @Int32()
  external int offsetMs;         // start offset in ms

  @Int32()
  external int durationMs;       // audio duration to process in ms

  @Int32()
  external int translate;        // 0 = transcribe, 1 = translate

  @Int32()
  external int noContext;        // 1 = do not use past transcription

  @Int32()
  external int noTimestamps;     // 1 = do not output timestamps

  external Pointer<Utf8> language; // "en", "auto", etc.

  @Int32()
  external int detectLanguage;   // 1 = detect language automatically

  @Int32()
  external int suppressBlank;    // 1 = suppress blank outputs

  @Int32()
  external int suppressNonSpeechTokens; // 1 = suppress non-speech tokens

  @Float()
  external double temperature;

  @Float()
  external double maxInitialTs;

  @Float()
  external double lengthPenalty;

  @Float()
  external double temperatureInc;

  @Float()
  external double entropyThresh;

  @Float()
  external double logProbThresh;

  @Float()
  external double noSpeechThresh;

  // Callbacks — stored as pointers (no annotations on Pointer fields)
  external Pointer<Void> newSegmentCallback;
  external Pointer<Void> newSegmentCallbackUserData;
  external Pointer<Void> progressCallback;
  external Pointer<Void> progressCallbackUserData;
  external Pointer<Void> abortCallback;
  external Pointer<Void> abortCallbackUserData;

  // Beam search
  @Int32()
  external int beamSize;

  @Int32()
  external int bestOf;

  // Greedy
  @Int32()
  external int patience;
}
