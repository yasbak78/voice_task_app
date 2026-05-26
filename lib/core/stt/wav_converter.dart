import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Converts audio files to whisper.cpp-compatible WAV format.
/// whisper.cpp requires: 16-bit PCM, mono, 16kHz sample rate.
class WavConverter {
  static const int _targetSampleRate = 16000;
  static const int _bitsPerSample = 16;
  static const int _numChannels = 1;

  /// Converts an audio file to whisper.cpp format.
  /// If already in correct format, returns original path.
  static Future<String> convertToWhisperFormat(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input file not found', inputPath);
    }

    final bytes = await inputFile.readAsBytes();
    if (_isAlreadyWhisperFormat(bytes)) {
      return inputPath;
    }

    final wavData = _convertTo16kHzMono16bit(bytes);
    
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/whisper_${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(outputPath).writeAsBytes(wavData);
    
    return outputPath;
  }

  static bool _isAlreadyWhisperFormat(Uint8List bytes) {
    if (bytes.length < 44) return false;
    // Check RIFF header
    if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
        bytes[2] != 0x46 || bytes[3] != 0x46) {
      return false;
    }
    // Check sample rate at offset 24
    final sampleRate = ByteData.sublistView(bytes, 24, 28).getUint32(0, Endian.little);
    // Check num channels at offset 22
    final channels = ByteData.sublistView(bytes, 22, 24).getUint16(0, Endian.little);
    // Check bits per sample at offset 34
    final bits = ByteData.sublistView(bytes, 34, 36).getUint16(0, Endian.little);
    
    return sampleRate == _targetSampleRate && 
           channels == _numChannels && 
           bits == _bitsPerSample;
  }

  static Uint8List _convertTo16kHzMono16bit(Uint8List inputBytes) {
    if (inputBytes.length < 44) {
      throw FormatException('Invalid WAV file: too small');
    }

    final pcmData = inputBytes.sublist(44);
    final header = _buildWavHeader(pcmData.length);
    
    final result = Uint8List(header.length + pcmData.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, header.length + pcmData.length, pcmData);
    return result;
  }

  static Uint8List _buildWavHeader(int dataSize) {
    final header = Uint8List(44);
    final bd = ByteData.view(header.buffer);
    
    // RIFF header
    header[0] = 0x52; // 'R'
    header[1] = 0x49; // 'I'
    header[2] = 0x46; // 'F'
    header[3] = 0x46; // 'F'
    bd.setUint32(4, 36 + dataSize, Endian.little); // File size
    header[8] = 0x57; // 'W'
    header[9] = 0x41; // 'A'
    header[10] = 0x56; // 'V'
    header[11] = 0x45; // 'E'
    
    // fmt chunk
    header[12] = 0x66; // 'f'
    header[13] = 0x6D; // 'm'
    header[14] = 0x74; // 't'
    header[15] = 0x20; // ' '
    bd.setUint32(16, 16, Endian.little); // Subchunk1 size
    bd.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    bd.setUint16(22, _numChannels, Endian.little);
    bd.setUint32(24, _targetSampleRate, Endian.little);
    bd.setUint32(28, _targetSampleRate * _numChannels * _bitsPerSample ~/ 8, Endian.little); // Byte rate
    bd.setUint16(32, _numChannels * _bitsPerSample ~/ 8, Endian.little); // Block align
    bd.setUint16(34, _bitsPerSample, Endian.little);
    
    // data chunk
    header[36] = 0x64; // 'd'
    header[37] = 0x61; // 'a'
    header[38] = 0x74; // 't'
    header[39] = 0x61; // 'a'
    bd.setUint32(40, dataSize, Endian.little);
    
    return header;
  }

  /// Validates a WAV file and returns its properties.
  static Future<WavInfo> validateWav(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw FormatException('Invalid WAV: file too small');
    }

    final bd = ByteData.sublistView(bytes);
    final sampleRate = bd.getUint32(24, Endian.little);
    final channels = bd.getUint16(22, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    final dataSize = bd.getUint32(40, Endian.little);
    final duration = dataSize / (sampleRate * channels * bitsPerSample ~/ 8);

    return WavInfo(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      duration: Duration(milliseconds: (duration * 1000).toInt()),
      isWhisperCompatible: sampleRate == _targetSampleRate && 
                          channels == _numChannels && 
                          bitsPerSample == _bitsPerSample,
    );
  }
}

class WavInfo {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Duration duration;
  final bool isWhisperCompatible;

  WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.duration,
    required this.isWhisperCompatible,
  });
}
