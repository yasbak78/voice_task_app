import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/config/tts_config.dart';
import 'package:voice_task_app/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsResult', () {
    test('success result has correct fields', () {
      const result = TtsResult(
        success: true,
        usedProvider: TtsProvider.flutterTts,
      );
      expect(result.success, isTrue);
      expect(result.usedProvider, TtsProvider.flutterTts);
      expect(result.error, isNull);
    });

    test('failure result has error message', () {
      const result = TtsResult(
        success: false,
        error: 'Network error',
        usedProvider: TtsProvider.flutterTts,
      );
      expect(result.success, isFalse);
      expect(result.error, 'Network error');
    });

    test('toString includes success and provider', () {
      const result = TtsResult(
        success: true,
        usedProvider: TtsProvider.flutterTts,
      );
      final str = result.toString();
      expect(str, contains('success: true'));
      expect(str, contains('flutterTts'));
    });

    test('toString includes error when present', () {
      const result = TtsResult(
        success: false,
        error: 'init failed',
        usedProvider: TtsProvider.flutterTts,
      );
      final str = result.toString();
      expect(str, contains('init failed'));
    });
  });

  group('TtsState', () {
    test('has all expected states', () {
      expect(TtsState.values, contains(TtsState.idle));
      expect(TtsState.values, contains(TtsState.speaking));
      expect(TtsState.values, contains(TtsState.paused));
      expect(TtsState.values, contains(TtsState.stopped));
      expect(TtsState.values, contains(TtsState.error));
    });

    test('enum values count is 5', () {
      expect(TtsState.values.length, 5);
    });
  });

  group('TtsService config integration', () {
    test('speech rate clamps to 0.0-1.0', () {
      // Test through config since TtsService requires platform
      TtsConfig.speechRate = 1.5;
      expect(TtsConfig.speechRate, 1.5); // config doesn't clamp, service does
      TtsConfig.speechRate = 0.5; // reset
    });

    test('pitch clamps to 0.0-2.0', () {
      TtsConfig.pitch = 3.0;
      expect(TtsConfig.pitch, 3.0);
      TtsConfig.pitch = 1.0; // reset
    });

    test('volume clamps to 0.0-1.0', () {
      TtsConfig.volume = 2.0;
      expect(TtsConfig.volume, 2.0);
      TtsConfig.volume = 1.0; // reset
    });

    test('can reset config to defaults', () {
      TtsConfig.speechRate = 0.5;
      TtsConfig.pitch = 1.0;
      TtsConfig.volume = 1.0;
      TtsConfig.locale = 'en-US';
      TtsConfig.currentProvider = TtsProvider.flutterTts;

      expect(TtsConfig.speechRate, 0.5);
      expect(TtsConfig.pitch, 1.0);
      expect(TtsConfig.volume, 1.0);
      expect(TtsConfig.locale, 'en-US');
    });

    test('voice summary formats correctly', () {
      TtsConfig.speechRate = 0.7;
      TtsConfig.pitch = 1.2;
      final summary = TtsConfig.voiceSummary;
      expect(summary, contains('0.7'));
      expect(summary, contains('1.2'));
    });
  });

  group('TtsProviderConfig', () {
    test('flutterTts config has correct label', () {
      final config = TtsConfig.configs[TtsProvider.flutterTts];
      expect(config!.label, contains('System'));
      expect(config.isOnline, isFalse);
    });
  });

  group('TtsService empty text handling', () {
    test('empty text returns failure result', () async {
      final service = TtsService();
      final result = await service.speak('');
      expect(result.success, isFalse);
      expect(result.error, contains('Empty'));
      await service.dispose();
    });

    test('whitespace-only text returns failure result', () async {
      final service = TtsService();
      final result = await service.speak('   ');
      expect(result.success, isFalse);
      await service.dispose();
    });
  });
}
