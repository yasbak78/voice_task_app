import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_task_app/screens/record/record_screen.dart';

void main() {
  group('RecordScreen', () {
    testWidgets('displays record button with mic icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordScreen(),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Tap to record'), findsOneWidget);
    });

    testWidgets('displays timer at 00:00 initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordScreen(),
          ),
        ),
      );

      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('shows state indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordScreen(),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('Processing'), findsOneWidget);
    });

    testWidgets('has correct app bar title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordScreen(),
        ),
      );

      expect(find.text('Record Task'), findsOneWidget);
    });

    testWidgets('record button is tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordScreen(),
          ),
        ),
      );

      final recordButton = find.byType(GestureDetector);
      expect(recordButton, findsOneWidget);
      expect(tester.widget<GestureDetector>(recordButton).onTap, isNotNull);
    });
  });
}
