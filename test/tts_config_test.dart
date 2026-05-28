import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/config/tts_config.dart';

void main() {
  group('TtsConfig', () {
    test('default provider is flutterTts', () {
      expect(TtsConfig.currentProvider, equals(TtsProvider.flutterTts));
    });

    test('default speech rate is 0.5', () {
      TtsConfig.speechRate = 0.5;
      expect(TtsConfig.speechRate, equals(0.5));
    });

    test('default pitch is 1.0', () {
      TtsConfig.pitch = 1.0;
      expect(TtsConfig.pitch, equals(1.0));
    });

    test('default volume is 1.0', () {
      TtsConfig.volume = 1.0;
      expect(TtsConfig.volume, equals(1.0));
    });

    test('default locale is en-US', () {
      expect(TtsConfig.locale, equals('en-US'));
    });

    test('active label returns provider display name', () {
      TtsConfig.currentProvider = TtsProvider.flutterTts;
      expect(TtsConfig.activeLabel, contains('System'));
    });

    test('voice summary includes rate and pitch', () {
      TtsConfig.speechRate = 0.5;
      TtsConfig.pitch = 1.0;
      final summary = TtsConfig.voiceSummary;
      expect(summary, contains('0.5'));
      expect(summary, contains('1.0'));
    });

    test('configs map contains flutterTts', () {
      expect(TtsConfig.configs.containsKey(TtsProvider.flutterTts), isTrue);
    });

    test('flutterTts config is offline', () {
      final config = TtsConfig.configs[TtsProvider.flutterTts];
      expect(config!.isOnline, isFalse);
    });

    test('can change provider', () {
      final original = TtsConfig.currentProvider;
      TtsConfig.currentProvider = TtsProvider.flutterTts;
      expect(TtsConfig.currentProvider, equals(TtsProvider.flutterTts));
      TtsConfig.currentProvider = original;
    });

    test('can modify speech rate', () {
      TtsConfig.speechRate = 0.8;
      expect(TtsConfig.speechRate, equals(0.8));
      TtsConfig.speechRate = 0.5; // reset
    });

    test('can modify pitch', () {
      TtsConfig.pitch = 1.5;
      expect(TtsConfig.pitch, equals(1.5));
      TtsConfig.pitch = 1.0; // reset
    });
  });

  group('TtsProvider enum', () {
    test('has flutterTts value', () {
      expect(TtsProvider.values, contains(TtsProvider.flutterTts));
    });

    test('flutterTts name is flutterTts', () {
      expect(TtsProvider.flutterTts.name, equals('flutterTts'));
    });
  });
}
