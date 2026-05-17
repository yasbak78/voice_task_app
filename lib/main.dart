import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home/task_list_screen.dart';

void main() {
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
        '/calendar': (context) => _placeholder('Calendar'),
        '/settings': (context) => _placeholder('Settings'),
        '/record': (context) => _placeholder('Record'),
        '/task-detail': (context) => _placeholder('Task Detail'),
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
