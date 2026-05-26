import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database/app_database.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';

/// TaskTile variant for multi-select mode.
class TaskTileMultiSelect extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TaskTileMultiSelect({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = AppColors.priority(context, task.priority);

    return AnimatedOpacity(
      opacity: isDone ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Stack(
            children: [
              // Left priority accent strip
              Container(
                width: 4,
                color: priorityColor.withValues(alpha: isDone ? 0.3 : 0.9),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : theme.colorScheme.surfaceContainerLowest,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: isDark ? 0.3 : 0.5,
                            ),
                      width: isSelected ? 2 : 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(
                          alpha: isDark ? 0.2 : 0.06,
                        ),
                        blurRadius: isDark ? 8 : 4,
                        offset: Offset(0, isDark ? 2 : 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Selection checkbox
                            _SelectionCheckbox(
                              isSelected: isSelected,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // Task content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16.5,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDone
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (task.project != null ||
                                      task.dueDate != null) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        if (task.project != null &&
                                            task.project!.isNotEmpty)
                                          _ProjectChip(name: task.project!),
                                        if (task.dueDate != null)
                                          _DueDateChip(
                                            date: task.dueDate!,
                                            isCompleted: isDone,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _PriorityBadge(priority: task.priority),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection checkbox for multi-select mode.
class _SelectionCheckbox extends StatelessWidget {
  final bool isSelected;

  const _SelectionCheckbox({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isSelected ? 0 : 2,
        ),
        color: isSelected
            ? theme.colorScheme.primary
            : Colors.transparent,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: theme.colorScheme.onPrimary,
                key: const ValueKey('checked'),
              )
            : const SizedBox(key: ValueKey('unchecked')),
      ),
    );
  }
}

/// Priority badge with icon.
class _PriorityBadge extends StatelessWidget {
  final Priority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.priority(context, priority);
    return Icon(Icons.flag, size: 18, color: color);
  }
}

/// Due date chip with relative date display.
class _DueDateChip extends StatelessWidget {
  final DateTime date;
  final bool isCompleted;

  const _DueDateChip({required this.date, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    String label;
    Color color;

    if (isCompleted) {
      label = _formatDate(date);
      color = theme.colorScheme.onSurfaceVariant;
    } else if (diff < 0) {
      label = diff == -1 ? 'Yesterday' : _formatDate(date);
      color = theme.colorScheme.error;
    } else if (diff == 0) {
      label = 'Today';
      color = AppColors.priority(context, Priority.high);
    } else if (diff == 1) {
      label = 'Tomorrow';
      color = AppColors.priority(context, Priority.medium);
    } else {
      label = _formatDate(date);
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_outlined, size: 12, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.base.labelSmall?.copyWith(
            color: color,
            fontWeight: diff < 0 && !isCompleted ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

/// Project chip for task tiles.
class _ProjectChip extends StatelessWidget {
  final String name;

  const _ProjectChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 10,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            name,
            style: AppTypography.base.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
