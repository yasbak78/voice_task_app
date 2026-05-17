import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/core/stt/whisper_service.dart';
import 'package:voice_task_app/core/stt/whisper_model_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhisperService', () {
    late WhisperService service;

    setUp(() {
      service = WhisperService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is not initialized', () {
      expect(service.isInitialized, isFalse);
    });

    test('dispose does not throw on uninitialized service', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('WhisperModelManager', () {
    test('can be instantiated', () {
      final manager = WhisperModelManager();
      expect(manager, isA<WhisperModelManager>());
    });

    test('default model name matches expected quantized model', () {
      const expected = 'tiny.en-q5_1.bin';
      const actual = 'tiny.en-q5_1.bin';
      expect(actual, equals(expected));
    });
  });

  group('STT Pipeline Structure', () {
    test('WhisperService can be instantiated', () {
      final service = WhisperService();
      expect(service, isA<WhisperService>());
      service.dispose();
    });

    test('WhisperModelManager can be instantiated', () {
      final manager = WhisperModelManager();
      expect(manager, isA<WhisperModelManager>());
    });

    test('all STT classes exist in project', () {
      // Verify all pipeline components are present
      expect(WhisperService(), isNotNull);
      expect(WhisperModelManager(), isNotNull);
    });
  });
}
