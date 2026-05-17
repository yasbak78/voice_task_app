import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('STT Model'),
            subtitle: Text('tiny.en-q5_1'),
          ),
          SwitchListTile(
            title: const Text('Use Silero VAD'),
            subtitle: const Text('Skip silence during recording'),
            value: true,
            onChanged: (v) {},
          ),
          const ListTile(
            title: Text('Whisper Threads'),
            subtitle: Text('2'),
            trailing: Icon(Icons.chevron_right),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (v) {},
          ),
          const ListTile(
            title: Text('About'),
            subtitle: Text('Voice Task App v1.0.0'),
          ),
        ],
      ),
    );
  }
}
