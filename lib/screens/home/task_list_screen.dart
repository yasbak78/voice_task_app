import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../providers/task_providers.dart';
import '../../widgets/task_tile.dart';
import '../../models/task_model.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildTaskList(context, ref, tasks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/record'),
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _buildTaskList(
      BuildContext context, WidgetRef ref, List<Task> tasks) {
    final pending =
        tasks.where((t) => t.status != TaskStatus.done).toList();
    final done =
        tasks.where((t) => t.status == TaskStatus.done).toList();
    final today = pending.where((t) => t.isDueToday).toList();
    final thisWeek = pending
        .where((t) => !t.isDueToday && t.isDueThisWeek)
        .toList();
    final later = pending
        .where((t) => !t.isDueToday && !t.isDueThisWeek)
        .toList();

    return ListView(
      children: [
        _buildSection('Today', today, context, ref),
        _buildSection('This Week', thisWeek, context, ref),
        _buildSection('Later', later, context, ref),
        if (done.isNotEmpty)
          _buildSection('Completed', done, context, ref),
      ],
    );
  }

  Widget _buildSection(
      String title, List<Task> tasks, BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...tasks.map((t) => TaskTile(
              task: t,
              onTap: () => _showTaskDetail(context, t),
              onComplete: () => _markComplete(ref, t),
            )),
      ],
    );
  }

  void _showTaskDetail(BuildContext context, Task task) {
    Navigator.pushNamed(context, '/task-detail', arguments: task);
  }

  void _markComplete(WidgetRef ref, Task task) {
    ref.read(taskDaoProvider).markComplete(task.id);
  }
}
