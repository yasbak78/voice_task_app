import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/core/theme/app_spacing.dart';
import '../../core/database/app_database.dart';
import '../../models/task_model.dart';
import '../../providers/task_providers.dart' show allTasksProvider, taskDaoProvider;

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime? _selectedDueDate;
  late Priority _selectedPriority;
  late String? _selectedProject;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _selectedDueDate = widget.task.dueDate;
    _selectedPriority = widget.task.priority;
    _selectedProject = widget.task.project;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      // Reset to original values on cancel
      _titleController.text = widget.task.title;
      _notesController.text = widget.task.notes ?? '';
      _selectedDueDate = widget.task.dueDate;
      _selectedPriority = widget.task.priority;
      _selectedProject = widget.task.project;
    }
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
    final dao = ref.read(taskDaoProvider);
    await (dao.update(dao.tasks)..where((t) => t.id.equals(widget.task.id)))
        .write(TasksCompanion(
      title: Value(_titleController.text.trim()),
      notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      dueDate: Value(_selectedDueDate),
      priority: Value(_selectedPriority),
      project: Value(_selectedProject),
    ));
    AppHaptics.complete();
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated')),
      );
    }
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      // After picking date, also pick time
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else if (pickedTime == null && mounted) {
        // User cancelled time — keep just the date at midnight
        setState(() {
          _selectedDueDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? const Text('Edit Task')
            : Text(widget.task.title),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            tooltip: _isEditing ? 'Cancel' : 'Edit',
            onPressed: _toggleEdit,
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Status & Priority Card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.task.status == TaskStatus.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: widget.task.status == TaskStatus.done
                            ? colorScheme.primary
                            : colorScheme.outline,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _isEditing
                            ? TextField(
                                controller: _titleController,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Task title',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              )
                            : Text(
                                widget.task.title,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _isEditing
                          ? _priorityDropdown(context)
                          : _chip(context, _selectedPriority.displayName, _priorityColor(_selectedPriority)),
                      _chip(context, widget.task.status.displayName, colorScheme.primary),
                      if (_selectedProject != null)
                        _isEditing
                            ? _projectChipWithEdit(context)
                            : _chip(context, '📁 $_selectedProject', colorScheme.secondary),
                      if (_selectedDueDate != null)
                        _isEditing
                            ? _dueDateChipWithEdit(context)
                            : _chip(
                                context,
                                'Due: ${_formatDate(_selectedDueDate!)}',
                                widget.task.isOverdue ? colorScheme.error : colorScheme.onSurface,
                              ),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_selectedDueDate == null ? 'Set due date' : 'Change date'),
                          onPressed: _pickDueDate,
                        ),
                        if (_selectedDueDate != null)
                          TextButton.icon(
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Remove'),
                            onPressed: () => setState(() => _selectedDueDate = null),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Notes ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_outlined, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Notes', style: textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _isEditing
                      ? TextField(
                          controller: _notesController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Add notes...',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : widget.task.notes != null && widget.task.notes!.isNotEmpty
                          ? Text(widget.task.notes!, style: textTheme.bodyMedium)
                          : Text('No notes', style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline)),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Timeline / Activity ──
          ExpansionTile(
            title: const Text('Activity'),
            leading: const Icon(Icons.history),
            initiallyExpanded: true,
            children: [
              _timelineTile(context, 'Created', widget.task.createdAt),
              if (widget.task.completedAt != null)
                _timelineTile(context, 'Completed', widget.task.completedAt!),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Related Tasks ──
          if (widget.task.project != null)
            _buildRelatedTasks(context, ref),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _priorityDropdown(BuildContext context) {
    return DropdownButton<Priority>(
      value: _selectedPriority,
      items: Priority.values.map((p) {
        return DropdownMenuItem(
          value: p,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: _priorityColor(p).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(p.displayName, style: TextStyle(color: _priorityColor(p), fontWeight: FontWeight.w600)),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedPriority = v);
      },
    );
  }

  Widget _projectChipWithEdit(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProjectPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📁 ${_selectedProject ?? "No project"}', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _dueDateChipWithEdit(BuildContext context) {
    return GestureDetector(
      onTap: _pickDueDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Due: ${_formatDate(_selectedDueDate!)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14),
          ],
        ),
      ),
    );
  }

  void _showProjectPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final projects = [null, 'Work', 'Personal', 'Health', 'Finance'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Select Project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...projects.map((p) => ListTile(
                title: Text(p ?? 'No project'),
                onTap: () {
                  setState(() => _selectedProject = p);
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelatedTasks(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    return tasksAsync.when(
      data: (allTasks) {
        final relatedTasks = allTasks
            .where((t) => t.project == widget.task.project && t.id != widget.task.id)
            .take(5)
            .toList();

        if (relatedTasks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpansionTile(
              title: const Text('Related Tasks'),
              leading: const Icon(Icons.link),
              initiallyExpanded: false,
              children: [
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: relatedTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final related = relatedTasks[index];
                      return SizedBox(
                        width: 160,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              AppHaptics.tap();
                              Navigator.pushNamed(
                                context,
                                '/task-detail',
                                arguments: related,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    related.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _priorityColor(related.priority),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        related.priority.displayName,
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _timelineTile(BuildContext context, String label, DateTime timestamp) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xs,
      ),
      leading: const Icon(Icons.circle, size: 8),
      title: Text(label),
      trailing: Text(
        _formatDateTime(timestamp),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Color _priorityColor(Priority priority) {
    return switch (priority) {
      Priority.high => const Color(0xFFE53935),
      Priority.medium => const Color(0xFFF59E0B),
      Priority.low => const Color(0xFF4A6FA5),
    };
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final base = '${months[date.month - 1]} ${date.day}, ${date.year}';
    // Show time only if it's not midnight
    if (date.hour != 0 || date.minute != 0) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$base $hour:$minute';
    }
    return base;
  }

  String _formatDateTime(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} $hour:$minute';
  }
}
