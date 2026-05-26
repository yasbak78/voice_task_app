import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/theme/app_spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sectionHeaderStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
      letterSpacing: 1.2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          // ── Appearance ──
          _buildSectionHeader('APPEARANCE', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  secondary: Icon(Icons.dark_mode_outlined,
                      color: colorScheme.primary),
                  title: const Text('Dark Mode'),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (v) {
                    AppHaptics.tap();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── Notifications ──
          _buildSectionHeader('NOTIFICATIONS', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  secondary: Icon(Icons.mic_outlined, color: colorScheme.primary),
                  title: const Text('Use Silero VAD'),
                  subtitle: const Text('Skip silence during recording'),
                  value: true,
                  onChanged: (v) {
                    AppHaptics.tap();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── Data Management ──
          _buildSectionHeader('DATA MANAGEMENT', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.model_training,
                      color: colorScheme.primary),
                  title: const Text('STT Model'),
                  subtitle: const Text('tiny.en-q5_1'),
                ),
                const Divider(height: 1, thickness: 0.5),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  leading: Icon(Icons.memory, color: colorScheme.primary),
                  title: const Text('Whisper Threads'),
                  subtitle: const Text('2'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          const Divider(height: AppSpacing.lg, thickness: 0.5),

          // ── About ──
          _buildSectionHeader('ABOUT', sectionHeaderStyle),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: Icon(Icons.info_outline, color: colorScheme.primary),
              title: const Text('About'),
              subtitle: const Text('Voice Task App v1.0.0'),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg + AppSpacing.sm,
        bottom: AppSpacing.xs,
        top: AppSpacing.sm,
      ),
      child: Text(title, style: style),
    );
  }
}
