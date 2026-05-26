import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ============================================================
// whisper.cpp FFI bindings — updated for whisper.cpp v1.7.x
// Uses `_by_ref` functions to avoid Dart FFI struct-by-value issues
// ============================================================

// --- whisper_context_params ---
base class WhisperContextParams extends Struct {
  @Bool()
  external bool useGpu;

  @Bool()
  external bool flashAttn;

  @Int32()
  external int gpuDevice;

  @Bool()
  external bool dtwTokenTimestamps;

  @Int32()
  external int dtwAheadsPreset;

  @Int32()
  external int dtwNTop;

  // dtw_aheads is a nested struct — skip for now (not needed for basic usage)
  external Pointer<Void> dtwAheads;

  @Uint64()
  external int dtwMemSize;
}

typedef WhisperContextDefaultParamsByRef = Pointer<WhisperContextParams> Function();
typedef WhisperContextDefaultParamsByRefDart = Pointer<WhisperContextParams> Function();

typedef WhisperInitFromFileWithParams = Pointer<Void> Function(
  Pointer<Utf8> pathModel,
  WhisperContextParams params,
);
typedef WhisperInitFromFileWithParamsDart = Pointer<Void> Function(
  Pointer<Utf8> pathModel,
  WhisperContextParams params,
);

// --- whisper_full_params ---
base class WhisperFullParams extends Struct {
  @Int32()
  external int strategy; // whisper_sampling_strategy

  @Int32()
  external int nThreads;

  @Int32()
  external int nMaxTextCtx;

  @Int32()
  external int offsetMs;

  @Int32()
  external int durationMs;

  @Bool()
  external bool translate;

  @Bool()
  external bool noContext;

  @Bool()
  external bool noTimestamps;

  @Bool()
  external bool singleSegment;

  @Bool()
  external bool printSpecial;

  @Bool()
  external bool printProgress;

  @Bool()
  external bool printRealtime;

  @Bool()
  external bool printTimestamps;

  @Bool()
  external bool tokenTimestamps;

  @Float()
  external double tholdPt;

  @Float()
  external double tholdPtsum;

  @Int32()
  external int maxLen;

  @Bool()
  external bool splitOnWord;

  @Int32()
  external int maxTokens;

  @Bool()
  external bool debugMode;

  @Int32()
  external int audioCtx;

  @Bool()
  external bool tdrzEnable;

  external Pointer<Utf8> suppressRegex;

  external Pointer<Utf8> initialPrompt;

  @Bool()
  external bool carryInitialPrompt;

  external Pointer<Uint16> promptTokens; // whisper_token* = int32*

  @Int32()
  external int promptNTokens;

  external Pointer<Utf8> language;

  @Bool()
  external bool detectLanguage;

  // Decoding params (partial — enough for our use)
  @Int32()
  external int beamSize;

  @Int32()
  external int bestOf;

  @Int32()
  external int patience;

  external Pointer<Void> greedy;

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

  // Callbacks
  external Pointer<Void> newSegmentCallback;
  external Pointer<Void> newSegmentCallbackUserData;
  external Pointer<Void> progressCallback;
  external Pointer<Void> progressCallbackUserData;
  external Pointer<Void> abortCallback;
  external Pointer<Void> abortCallbackUserData;

  // Extra arrays (skip for now)
  external Pointer<Void> extra;
  external Pointer<Int32> debugView;
  external Pointer<Int32> debugViewLen;

  @Bool()
  external bool useGpu;

  @Float()
  external double grammarPenalty;
}

typedef WhisperFullDefaultParamsByRef = Pointer<WhisperFullParams> Function(Int32 strategy);
typedef WhisperFullDefaultParamsByRefDart = Pointer<WhisperFullParams> Function(int strategy);

// whisper_full
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

// whisper_full_n_segments
typedef WhisperFullNSegments = Int32 Function(Pointer<Void> ctx);
typedef WhisperFullNSegmentsDart = int Function(Pointer<Void> ctx);

// whisper_full_get_segment_text
typedef WhisperFullGetSegmentText = Pointer<Utf8> Function(
  Pointer<Void> ctx,
  Int32 iSegment,
);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(
  Pointer<Void> ctx,
  int iSegment,
);

// whisper_free
typedef WhisperFree = Void Function(Pointer<Void> ctx);
typedef WhisperFreeDart = void Function(Pointer<Void> ctx);

// whisper_free_context_params
typedef WhisperFreeContextParams = Void Function(Pointer<WhisperContextParams> params);
typedef WhisperFreeContextParamsDart = void Function(Pointer<WhisperContextParams> params);

// whisper_free_params
typedef WhisperFreeParams = Void Function(Pointer<WhisperFullParams> params);
typedef WhisperFreeParamsDart = void Function(Pointer<WhisperFullParams> params);

/// FFI bindings to whisper.cpp shared library.
class WhisperFFI {
  static WhisperFFI? _instance;
  late final DynamicLibrary _lib;

  late final Pointer<WhisperContextParams> Function() whisperContextDefaultParamsByRef;
  late final Pointer<WhisperFullParams> Function(int) whisperFullDefaultParamsByRef;
  late final Pointer<Void> Function(Pointer<Utf8>, WhisperContextParams) whisperInitFromFileWithParams;
  late final int Function(Pointer<Void>, Pointer<WhisperFullParams>, Pointer<Float>, int) whisperFull;
  late final int Function(Pointer<Void>) whisperFullNSegments;
  late final Pointer<Utf8> Function(Pointer<Void>, int) whisperFullGetSegmentText;
  late final void Function(Pointer<Void>) whisperFree;
  late final void Function(Pointer<WhisperContextParams>) whisperFreeContextParams;
  late final void Function(Pointer<WhisperFullParams>) whisperFreeParams;

  WhisperFFI._();

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

    whisperContextDefaultParamsByRef = _lib.lookupFunction<
        WhisperContextDefaultParamsByRef,
        WhisperContextDefaultParamsByRefDart>('whisper_context_default_params_by_ref');

    whisperFullDefaultParamsByRef = _lib.lookupFunction<
        WhisperFullDefaultParamsByRef,
        WhisperFullDefaultParamsByRefDart>('whisper_full_default_params_by_ref');

    whisperInitFromFileWithParams = _lib.lookupFunction<
        WhisperInitFromFileWithParams,
        WhisperInitFromFileWithParamsDart>('whisper_init_from_file_with_params');

    whisperFull = _lib.lookupFunction<WhisperFull, WhisperFullDart>('whisper_full');

    whisperFullNSegments = _lib.lookupFunction<
        WhisperFullNSegments,
        WhisperFullNSegmentsDart>('whisper_full_n_segments');

    whisperFullGetSegmentText = _lib.lookupFunction<
        WhisperFullGetSegmentText,
        WhisperFullGetSegmentTextDart>('whisper_full_get_segment_text');

    whisperFree = _lib.lookupFunction<WhisperFree, WhisperFreeDart>('whisper_free');

    whisperFreeContextParams = _lib.lookupFunction<
        WhisperFreeContextParams,
        WhisperFreeContextParamsDart>('whisper_free_context_params');

    whisperFreeParams = _lib.lookupFunction<WhisperFreeParams, WhisperFreeParamsDart>('whisper_free_params');
  }

  static bool get isAvailable {
    try {
      instance;
      return true;
    } catch (_) {
      return false;
    }
  }
}
