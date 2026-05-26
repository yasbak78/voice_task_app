import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages whisper model files — loads from bundled assets first,
/// with HuggingFace download as fallback.
class WhisperModelManager {
  static const String _defaultModelName = 'ggml-tiny.en-q5_1.bin';
  static const String _defaultModelUrl = 
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin';

  /// Returns the local path to the model file.
  /// Copies from bundled assets if not present. Falls back to HF download.
  Future<String> getModelPath({
    String? modelName,
    void Function(double progress)? onProgress,
  }) async {
    final name = modelName ?? _defaultModelName;
    
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}/whisper_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final modelPath = '${modelDir.path}/$name';
    
    // Return if already cached
    final file = File(modelPath);
    if (await file.exists() && await file.length() > 1000000) {
      return modelPath;
    }

    // Try loading from bundled assets first
    try {
      await _copyFromAssets(name, modelPath, onProgress);
      return modelPath;
    } catch (e) {
      // Fallback: download from HuggingFace
      debugPrint('Asset load failed ($e), falling back to HuggingFace download');
      await _downloadModel(_defaultModelUrl, modelPath, onProgress);
      return modelPath;
    }
  }

  /// Copies model from Flutter assets to local storage.
  Future<void> _copyFromAssets(
    String name,
    String destPath,
    void Function(double progress)? onProgress,
  ) async {
    debugPrint('Loading model from assets: $name');
    final data = await rootBundle.load('assets/models/$name');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    
    debugPrint('Asset size: ${bytes.length} bytes');
    
    // Write in chunks with progress callback
    final file = File(destPath);
    final sink = file.openWrite();
    
    const chunkSize = 65536; // 64KB
    int written = 0;
    
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      sink.add(bytes.sublist(i, end));
      written += (end - i);
      
      if (onProgress != null) {
        onProgress(written / bytes.length);
      }
    }
    
    await sink.close();
    
    // Verify
    final finalSize = await file.length();
    if (finalSize < 1000000) {
      throw Exception('Asset copy verification failed: only $finalSize bytes written');
    }
    
    debugPrint('Model copied to local storage: $finalSize bytes');
  }

  /// Downloads a model from URL with progress callbacks.
  Future<void> _downloadModel(
    String url, 
    String destPath, 
    void Function(double progress)? onProgress,
  ) async {
    debugPrint('Downloading model from HuggingFace: $url');
    
    // Retry up to 3 times with increasing delays
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await request.send();
        
        if (response.statusCode != 200) {
          throw HttpException(
            'Failed to download model: HTTP ${response.statusCode}',
            uri: Uri.parse(url),
          );
        }

        final contentLength = response.contentLength ?? 0;
        int downloaded = 0;
        final file = File(destPath);
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          
          if (contentLength > 0 && onProgress != null) {
            onProgress(downloaded / contentLength);
          }
        }
        
        await sink.close();
        
        // Verify
        final finalSize = await file.length();
        if (finalSize < 1000000) {
          throw Exception('Download verification failed: only $finalSize bytes');
        }
        
        debugPrint('Model downloaded: $finalSize bytes');
        return;
      } catch (e) {
        debugPrint('Download attempt $attempt failed: $e');
        if (attempt == 3) {
          rethrow;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Checks if a model is already cached.
  Future<bool> isModelCached({String? modelName}) async {
    final name = modelName ?? _defaultModelName;
    final dir = await getApplicationSupportDirectory();
    final modelPath = '${dir.path}/whisper_models/$name';
    final file = File(modelPath);
    return await file.exists() && await file.length() > 1000000;
  }

  /// Deletes cached models to free space.
  Future<void> clearCache() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}/whisper_models');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
  }

  /// Gets the size of cached models in bytes.
  Future<int> getCacheSize() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}/whisper_models');
    if (!await modelDir.exists()) return 0;
    
    int total = 0;
    await for (final file in modelDir.list()) {
      if (file is File) {
        total += await file.length();
      }
    }
    return total;
  }
}
