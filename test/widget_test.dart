import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/main.dart';

void main() {
  testWidgets('VoiceTaskApp is defined', (WidgetTester tester) async {
    // Verify the app widget can be instantiated
    const app = VoiceTaskApp();
    expect(app, isA<VoiceTaskApp>());
  });
}
