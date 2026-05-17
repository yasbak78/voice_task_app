import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'screens/home/task_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/task_detail/task_detail_screen.dart';
import 'screens/preview/preview_screen.dart';
import 'screens/calendar/calendar_screen.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const TaskListScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/record': (context) => const RecordScreen(),
        PreviewScreen.route: (context) => const PreviewScreen(transcription: 'Sample task for testing'),
      },
      onGenerateRoute: (settings) {
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

  Widget _placeholder(String title) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — Coming Soon')),
    );
  }
}
