import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages whisper model files (download, cache, verification).
class WhisperModelManager {
  static const String _defaultModelUrl = 
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin';
  static const String _defaultModelName = 'ggml-tiny.en-q5_1.bin';

  /// Returns the local path to the model file.
  /// Downloads if not present in cache.
  Future<String> getModelPath({
    String? modelName,
    String? modelUrl,
    void Function(double progress)? onProgress,
  }) async {
    final name = modelName ?? _defaultModelName;
    final url = modelUrl ?? _defaultModelUrl;
    
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}/whisper_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final modelPath = '${modelDir.path}/$name';
    
    if (await File(modelPath).exists()) {
      return modelPath;
    }

    await _downloadModel(url, modelPath, onProgress);
    return modelPath;
  }

  /// Downloads a model from URL with progress callbacks.
  Future<void> _downloadModel(
    String url, 
    String destPath, 
    void Function(double progress)? onProgress,
  ) async {
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
  }

  /// Checks if a model is already cached.
  Future<bool> isModelCached({String? modelName}) async {
    final name = modelName ?? _defaultModelName;
    final dir = await getApplicationSupportDirectory();
    final modelPath = '${dir.path}/whisper_models/$name';
    return File(modelPath).exists();
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
