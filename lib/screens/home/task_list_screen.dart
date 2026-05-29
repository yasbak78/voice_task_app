import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/app_database.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_components.dart';
import '../../providers/task_providers.dart';
import '../../models/task_model.dart';
import '../../services/haptic_feedback_service.dart';
import '../../services/sound_preview_service.dart';

// --- Search & filter state providers (overrideable in tests) ---
final searchQueryProvider = StateProvider<String>((ref) => '');
final filterProjectsProvider = StateProvider<Set<String>>((ref) => {});
final filterPriorityProvider = StateProvider<String?>((ref) => null);
final filterDateRangeProvider = StateProvider<String>((ref) => 'all');

/// Computed provider: filters tasks based on current search/filter state.
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasksAsync = ref.watch(allTasksProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final projects = ref.watch(filterProjectsProvider);
  final priority = ref.watch(filterPriorityProvider);
  final dateRange = ref.watch(filterDateRangeProvider);

  return tasksAsync.when(
    data: (tasks) {
      // Only exclude done tasks when filters are active (user is searching/filtering)
      // When no filters are active, include all tasks (done tasks shown in Completed section)
      final hasFilters = query.isNotEmpty ||
          projects.isNotEmpty ||
          priority != null ||
          dateRange != 'all';

      var result = hasFilters
          ? tasks.where((t) => t.status != TaskStatus.done).toList()
          : tasks.toList();

      if (query.isNotEmpty) {
        result = result.where((t) {
          final titleMatch = t.title.toLowerCase().contains(query);
          final notesMatch = t.notes?.toLowerCase().contains(query) ?? false;
          return titleMatch || notesMatch;
        }).toList();
      }

      if (projects.isNotEmpty) {
        result = result.where((t) => projects.contains(t.project)).toList();
      }

      if (priority != null) {
        result = result.where((t) => t.priority.name == priority).toList();
      }

      if (dateRange == 'today') {
        result = result.where((t) => t.isDueToday).toList();
      } else if (dateRange == 'week') {
        result = result.where((t) => t.isDueThisWeek).toList();
      } else if (dateRange == 'overdue') {
        result = result.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.isBefore(DateTime.now()) && t.status != TaskStatus.done;
        }).toList();
      }

      return result;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// How many filters are currently active.
final activeFilterCountProvider = Provider<int>((ref) {
  int count = 0;
  if (ref.watch(filterProjectsProvider).isNotEmpty) count++;
  if (ref.watch(filterPriorityProvider) != null) count++;
  if (ref.watch(filterDateRangeProvider) != 'all') count++;
  return count;
});

String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, Yassin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            tasksAsync.maybeWhen(
              data: (tasks) {
                final pending = tasks.where((t) => t.status != TaskStatus.done).length;
                return Text(
                  pending == 0
                    ? 'All caught up!'
                    : 'You have $pending ${pending == 1 ? 'task' : 'tasks'} today',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        elevation: 2,
      ),
      body: tasksAsync.when(
        data: (tasks) => _buildTaskList(context, ref, tasks),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTaskList(
      BuildContext context, WidgetRef ref, List<Task> tasks) {
    final filteredTasks = ref.watch(filteredTasksProvider);
    final pending = tasks.where((t) => t.status != TaskStatus.done).toList();
    final activeCount = ref.watch(activeFilterCountProvider);

    return Column(
      children: [
        // Search bar + filter button row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                taskCount: pending.length,
                activeFilters: activeCount,
                onTap: () => _showFilterSheet(context),
              ),
            ],
          ),
        ),

        // Active filter chips row
        if (activeCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (ref.watch(filterDateRangeProvider) != 'all')
                  _ActiveFilterChip(
                    label: ref.watch(filterDateRangeProvider) == 'today'
                        ? 'Today'
                        : ref.watch(filterDateRangeProvider) == 'week'
                            ? 'This Week'
                            : 'Overdue',
                    onClear: () => ref.read(filterDateRangeProvider.notifier).state = 'all',
                  ),
                if (ref.watch(filterPriorityProvider) != null)
                  _ActiveFilterChip(
                    label: ref.watch(filterPriorityProvider)![0].toUpperCase() +
                        ref.watch(filterPriorityProvider)!.substring(1),
                    onClear: () => ref.read(filterPriorityProvider.notifier).state = null,
                  ),
                ...ref.watch(filterProjectsProvider).map(
                      (p) => _ActiveFilterChip(
                        label: p,
                        onClear: () {
                          final s = Set<String>.from(ref.read(filterProjectsProvider));
                          s.remove(p);
                          ref.read(filterProjectsProvider.notifier).state = s;
                        },
                      ),
                    ),
              ],
            ),
          ),

        Expanded(
          child: _buildSectionedList(context, ref, filteredTasks),
        ),
      ],
    );
  }

  Widget _buildSectionedList(
      BuildContext context, WidgetRef ref, List<Task> filteredTasks) {
    // Distinguish between "no tasks at all" vs "filters returned nothing"
    final allTasks = ref.watch(allTasksProvider);
    final totalTasks = allTasks.valueOrNull ?? [];

    if (totalTasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'All caught up!',
        subtitle: 'Tap the mic button to add your first task by voice',
      );
    }

    if (filteredTasks.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching tasks',
        subtitle: 'Try adjusting your search or filters',
      );
    }

    final today = filteredTasks.where((t) => t.isDueToday).toList();
    final thisWeek = filteredTasks
        .where((t) => !t.isDueToday && t.isDueThisWeek)
        .toList();
    final later = filteredTasks
        .where((t) => !t.isDueToday && !t.isDueThisWeek)
        .toList();
    final done = filteredTasks.where((t) => t.status == TaskStatus.done).toList();

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
        SectionHeader(
          title: title,
          count: tasks.length,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        ...tasks.map((t) => TaskCard(
              task: t,
              onTap: () => _showTaskDetail(context, t),
              onComplete: () => _markComplete(ref, t),
              onLongPress: () => _showQuickEditSheet(context, ref, t),
            )),
      ],
    );
  }

  void _showTaskDetail(BuildContext context, Task task) {
    Navigator.pushNamed(context, '/task-detail', arguments: task);
  }

  void _markComplete(WidgetRef ref, Task task) {
    final dao = ref.read(taskDaoProvider);
    final isDone = task.completedAt != null;
    if (isDone) {
      dao.markIncomplete(task.id);
      AppHaptics.navigate();
    } else {
      dao.markComplete(task.id);
      // Phase 3: Haptic + chime on task completion
      AppHaptics.complete();
      HapticFeedbackService.trigger('heavy');
      SoundPreviewService.playChime(sound: 'completion_chime');
    }
  }

  void _showQuickEditSheet(BuildContext context, WidgetRef ref, Task task) {
    final titleController = TextEditingController(text: task.title);
    final notesController = TextEditingController(text: task.notes ?? '');
    final isDone = task.completedAt != null;
    DateTime? selectedDueDate = task.dueDate;

    Future<void> pickTime() async {
      final pickedDate = selectedDueDate == null
          ? await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            )
          : null;
      if (!context.mounted) return; // ignore: use_build_context_synchronously
      DateTime baseDate = pickedDate ?? selectedDueDate ?? DateTime.now();
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(baseDate),
      );
      if (pickedTime != null) {
        selectedDueDate = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Quick Edit',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        selectedDueDate == null
                            ? 'Set due date'
                            : _formatQuickEditDate(selectedDueDate!),
                      ),
                      onPressed: () async {
                        await pickTime();
                        setSheetState(() {});
                      },
                    ),
                  ),
                  if (selectedDueDate != null)
                    const SizedBox(width: 8),
                  if (selectedDueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        selectedDueDate = null;
                        setSheetState(() {});
                      },
                      tooltip: 'Remove due date',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) return;
                        final dao = ref.read(taskDaoProvider);
                        (dao.update(dao.tasks)
                              ..where((t) => t.id.equals(task.id)))
                            .write(TasksCompanion(
                          title: Value(titleController.text.trim()),
                          notes: Value(notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim()),
                          dueDate: Value(selectedDueDate),
                        ));
                        AppHaptics.complete();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final dao = ref.read(taskDaoProvider);
                        if (isDone) {
                          await dao.markIncomplete(task.id);
                        } else {
                          await dao.markComplete(task.id);
                        }
                        AppHaptics.complete();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(isDone ? Icons.undo_rounded : Icons.check_rounded),
                      label: Text(isDone ? 'Undo Done' : 'Mark Done'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuickEditDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final base = '${months[date.month - 1]} ${date.day}';
    if (date.hour != 0 || date.minute != 0) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$base $hour:$minute';
    }
    return base;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) =>
            _FilterSheet(scrollController: scrollController),
      ),
    );
  }
}

/// Active filter chip shown below the search bar when filters are active.
class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _ActiveFilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        onClear();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: theme.colorScheme.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

/// Filter button with badge showing active filter count.
class _FilterButton extends StatelessWidget {
  final int taskCount;
  final int activeFilters;
  final VoidCallback onTap;

  const _FilterButton({
    required this.taskCount,
    required this.activeFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              color: activeFilters > 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            if (activeFilters > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeFilters',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filter modal sheet.
class _FilterSheet extends ConsumerWidget {
  final ScrollController scrollController;
  const _FilterSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Row(
            children: [
              Text('Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(filterProjectsProvider.notifier).state = {};
                  ref.read(filterPriorityProvider.notifier).state = null;
                  ref.read(filterDateRangeProvider.notifier).state = 'all';
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Date Range', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip('All Time', ref.watch(filterDateRangeProvider) == 'all',
                  () => ref.read(filterDateRangeProvider.notifier).state = 'all'),
              _FilterChip('Today', ref.watch(filterDateRangeProvider) == 'today',
                  () => ref.read(filterDateRangeProvider.notifier).state = 'today'),
              _FilterChip('This Week', ref.watch(filterDateRangeProvider) == 'week',
                  () => ref.read(filterDateRangeProvider.notifier).state = 'week'),
              _FilterChip('Overdue', ref.watch(filterDateRangeProvider) == 'overdue',
                  () => ref.read(filterDateRangeProvider.notifier).state = 'overdue'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Priority', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip('High', ref.watch(filterPriorityProvider) == 'high',
                  () => _togglePriority(ref, 'high')),
              _FilterChip('Medium', ref.watch(filterPriorityProvider) == 'medium',
                  () => _togglePriority(ref, 'medium')),
              _FilterChip('Low', ref.watch(filterPriorityProvider) == 'low',
                  () => _togglePriority(ref, 'low')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Project', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip('Work', ref.watch(filterProjectsProvider).contains('Work'),
                  () => _toggleProject(ref, 'Work')),
              _FilterChip('Personal', ref.watch(filterProjectsProvider).contains('Personal'),
                  () => _toggleProject(ref, 'Personal')),
              _FilterChip('Shopping', ref.watch(filterProjectsProvider).contains('Shopping'),
                  () => _toggleProject(ref, 'Shopping')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AppHaptics.complete();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _togglePriority(WidgetRef ref, String priority) {
    final current = ref.read(filterPriorityProvider);
    ref.read(filterPriorityProvider.notifier).state =
        current == priority ? null : priority;
  }

  void _toggleProject(WidgetRef ref, String project) {
    final projects = Set<String>.from(ref.read(filterProjectsProvider));
    if (projects.contains(project)) {
      projects.remove(project);
    } else {
      projects.add(project);
    }
    ref.read(filterProjectsProvider.notifier).state = projects;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : null,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
