import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'screens/main_shell.dart';
import 'screens/task_detail/task_detail_screen.dart';
import 'screens/preview/preview_screen.dart';
import 'screens/record/record_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: VoiceTaskApp()));
}

class VoiceTaskApp extends StatelessWidget {
  const VoiceTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Tasks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const MainShell(),
      routes: {
        '/record': (context) => const RecordScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == PreviewScreen.route) {
          final transcription = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => PreviewScreen(transcription: transcription),
          );
        }
        if (settings.name == '/task-detail' && settings.arguments is Task) {
          return MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
                task: settings.arguments as Task),
          );
        }
        return null;
      },
    );
  }
}
