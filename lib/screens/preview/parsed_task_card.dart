import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/parser/task_parser.dart';
import '../../core/theme/app_spacing.dart';

/// Editable task state for multi-task preview cards.
class EditableTask {
  final int id;
  String title;
  String notes;
  Priority priority;
  DateTime? dueDate;
  bool hasReminder;
  TimeOfDay? reminderTime;
  String project;

  // Controllers are managed by the card widget, stored here for convenience
  TextEditingController? titleController;
  TextEditingController? notesController;
  TextEditingController? projectController;
  bool isDeleted = false;

  EditableTask({
    required this.id,
    required this.title,
    this.notes = '',
    this.priority = Priority.medium,
    this.dueDate,
    this.hasReminder = false,
    this.reminderTime,
    this.project = '',
  });

  factory EditableTask.fromParsed(ParsedTask task, int index) {
    TimeOfDay? reminderTime;
    if (task.dueTime != null) {
      reminderTime = TimeOfDay(
        hour: task.dueTime!.hour,
        minute: task.dueTime!.minute,
      );
    }
    return EditableTask(
      id: index,
      title: task.title,
      notes: task.notes ?? '',
      priority: task.priority,
      dueDate: task.dueDate,
      hasReminder: task.hasReminder,
      reminderTime: reminderTime,
      project: task.project ?? '',
    );
  }

  void initControllers() {
    titleController = TextEditingController(text: title);
    notesController = TextEditingController(text: notes);
    projectController = TextEditingController(text: project);
  }

  void disposeControllers() {
    titleController?.dispose();
    notesController?.dispose();
    projectController?.dispose();
  }

  void syncFromControllers() {
    title = titleController?.text ?? title;
    notes = notesController?.text ?? notes;
    project = projectController?.text ?? project;
  }

  Color get priorityColor {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.amber;
      case Priority.low:
        return Colors.blue;
    }
  }

  IconData get priorityIcon {
    switch (priority) {
      case Priority.high:
        return Icons.arrow_upward;
      case Priority.medium:
        return Icons.remove;
      case Priority.low:
        return Icons.arrow_downward;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case Priority.high:
        return 'High';
      case Priority.medium:
        return 'Medium';
      case Priority.low:
        return 'Low';
    }
  }
}

/// A single editable task card for multi-task preview.
class EditableTaskCard extends StatefulWidget {
  final EditableTask task;
  final VoidCallback onDelete;
  final List<String> existingProjects;
  final Function(List<String>) onFilterSuggestions;
  final Future<DateTime?> Function(BuildContext, DateTime?) onSelectDate;
  final Future<TimeOfDay?> Function(BuildContext, TimeOfDay?) onSelectTime;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  const EditableTaskCard({
    super.key,
    required this.task,
    required this.onDelete,
    required this.existingProjects,
    required this.onFilterSuggestions,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  State<EditableTaskCard> createState() => _EditableTaskCardState();
}

class _EditableTaskCardState extends State<EditableTaskCard> {
  bool _notesExpanded = false;
  final List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    widget.task.initControllers();
    widget.task.projectController?.addListener(_onProjectChanged);
  }

  @override
  void dispose() {
    widget.task.projectController?.removeListener(_onProjectChanged);
    super.dispose();
  }

  void _onProjectChanged() {
    final text = widget.task.projectController?.text.toLowerCase() ?? '';
    setState(() {
      _filteredSuggestions.clear();
      if (text.isNotEmpty) {
        _filteredSuggestions.addAll(
          widget.existingProjects
              .where((p) => p.toLowerCase().contains(text))
              .take(5),
        );
      }
    });
    widget.onFilterSuggestions(_filteredSuggestions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(widget.task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Remove "${widget.task.title}" from the list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) {

        widget.onDelete();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border(
            left: BorderSide(
              color: widget.task.isDeleted
                  ? Colors.transparent
                  : widget.task.priorityColor.withValues(alpha: 0.7),
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: task number + delete button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: widget.task.priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '#${widget.task.id + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.task.priorityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: widget.task.titleController,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Task title',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      maxLines: 2,
                      onChanged: (v) => widget.task.title = v,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {

                      widget.onDelete();
                    },
                    tooltip: 'Remove task',
                  ),
                ],
              ),

              // Priority selector
              Row(
                children: [
                  Icon(widget.task.priorityIcon,
                      size: 16, color: widget.task.priorityColor),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: SegmentedButton<Priority>(
                      segments: const [
                        ButtonSegment<Priority>(
                          value: Priority.low,
                          icon: Icon(Icons.arrow_downward, size: 14),
                        ),
                        ButtonSegment<Priority>(
                          value: Priority.medium,
                          icon: Icon(Icons.remove, size: 14),
                        ),
                        ButtonSegment<Priority>(
                          value: Priority.high,
                          icon: Icon(Icons.arrow_upward, size: 14),
                        ),
                      ],
                      selected: {widget.task.priority},
                      onSelectionChanged: (selected) {
                        setState(() => widget.task.priority = selected.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs, vertical: 0),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),

              // Date & Time row
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  // Date chip
                  ActionChip(
                    avatar: Icon(Icons.calendar_today_outlined,
                        size: 16,
                        color: widget.task.dueDate != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                    label: Text(
                      widget.task.dueDate != null
                          ? _formatDate(widget.task.dueDate!)
                          : 'No date',
                      style: theme.textTheme.labelSmall,
                    ),
                    onPressed: () async {
                      final picked = await widget.onSelectDate(
                          context, widget.task.dueDate);
                      if (picked != null && mounted) {
                        setState(() {
                          widget.task.dueDate = picked;
                          widget.onDateChanged(picked);
                        });
                      }
                    },
                    backgroundColor: widget.task.dueDate != null
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  // Quick date chips
                  _quickDateChip(context, theme, 'Today', 0),

                  // Time chip (only if dueDate is set)
                  if (widget.task.dueDate != null)
                    ActionChip(
                      avatar: Icon(Icons.access_time,
                          size: 16,
                          color: widget.task.hasReminder
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.onSurfaceVariant),
                      label: Text(
                        widget.task.reminderTime != null
                            ? widget.task.reminderTime!.format(context)
                            : 'No time',
                        style: theme.textTheme.labelSmall,
                      ),
                      onPressed: () async {
                        final picked = await widget.onSelectTime(
                            context, widget.task.reminderTime ?? TimeOfDay.now());
                        if (picked != null && mounted) {
                          setState(() {
                            widget.task.reminderTime = picked;
                            widget.task.hasReminder = true;
                            widget.onTimeChanged(picked);
                          });
                        }
                      },
                      backgroundColor: widget.task.hasReminder
                          ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                ],
              ),

              // Notes (collapsed by default)
              AnimatedCrossFade(
                firstChild: GestureDetector(
                  onTap: () => setState(() => _notesExpanded = true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_outlined,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.task.notes.isNotEmpty
                            ? (widget.task.notes.length > 30
                                ? '${widget.task.notes.substring(0, 30)}...'
                                : widget.task.notes)
                            : 'Add notes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: widget.task.notesController,
                      style: theme.textTheme.bodySmall,
                      decoration: const InputDecoration(
                        hintText: 'Add notes...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      maxLines: 3,
                      onChanged: (v) => widget.task.notes = v,
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _notesExpanded = false),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.expand_less, size: 16),
                          Text('Collapse',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState:
                    _notesExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),

              // Project field with autocomplete
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: widget.task.projectController,
                      style: theme.textTheme.bodySmall,
                      decoration: const InputDecoration(
                        hintText: 'Project (optional)',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => widget.task.project = v,
                    ),
                  ),
                ],
              ),
              if (_filteredSuggestions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSuggestions.length,
                    itemBuilder: (context, i) {
                      final suggestion = _filteredSuggestions[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(Icons.folder,
                            size: 16, color: theme.colorScheme.primary),
                        title: Text(suggestion,
                            style: theme.textTheme.bodySmall),
                        onTap: () {
                          widget.task.projectController?.text = suggestion;
                          widget.task.project = suggestion;
                          setState(() => _filteredSuggestions.clear());
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickDateChip(BuildContext context, ThemeData theme, String label, int offset) {
    return FilterChip(
      label: Text(label, style: theme.textTheme.labelSmall),
      selected: widget.task.dueDate != null &&
          _isDateOffset(widget.task.dueDate!, offset),
      onSelected: (selected) {
        if (selected) {
          final date = DateTime.now().add(Duration(days: offset));
          final normalized = DateTime(date.year, date.month, date.day);
          setState(() {
            widget.task.dueDate = normalized;
            widget.onDateChanged(normalized);
          });
        }
      },
      showCheckmark: false,
      selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
    );
  }

  bool _isDateOffset(DateTime date, int offset) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day + offset);
    return date.year == target.year &&
        date.month == target.month &&
        date.day == target.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == tomorrow) return 'Tomorrow';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
