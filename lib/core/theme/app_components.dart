import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/app_database.dart';
import '../../core/haptics/app_haptics.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// Priority badge — colored pill with icon and label.
class PriorityBadge extends StatelessWidget {
  final Priority priority;
  final bool showLabel;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
  });

  IconData get _icon => Icons.flag_rounded;

  String get _label => switch (priority) {
        Priority.high => 'High',
        Priority.medium => 'Med',
        Priority.low => 'Low',
      };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.priority(context, priority);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? AppSpacing.sm : AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: color),
          if (showLabel) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              _label,
              style: AppTypography.base.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Due date chip — shows relative date with color coding.
class DueDateChip extends StatelessWidget {
  final DateTime date;
  final bool isCompleted;

  const DueDateChip({
    super.key,
    required this.date,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    String label;
    Color color;
    final diff = target.difference(today).inDays;

    if (isCompleted) {
      label = _formatDate(date);
      color = theme.colorScheme.onSurfaceVariant;
    } else if (diff < 0) {
      label = diff == -1 ? 'Yesterday' : _formatDate(date);
      color = AppColors.error(context);
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
        Icon(
          Icons.calendar_today_rounded,
          size: 12,
          color: color,
        ),
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
    return DateFormat('MMM d').format(d);
  }
}

/// Section header with optional action button and accent line.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  final Color? accentColor;
  final int? count;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.accentColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: (accentColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: AppTypography.base.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Rich empty state widget with icon, title, subtitle, and optional action.
/// Features: large icon with subtle background circle, bold title, descriptive subtitle.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String? actionLabel;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.iconSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large icon with subtle background circle
            Container(
              width: iconSize + 24,
              height: iconSize + 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Bold title
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel ?? 'Create Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// TaskCard — card-based task item replacing TaskTile.
/// Features: rounded corners, checkbox, priority badge, due date chip.
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final bool showShadow;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onDelete,
    this.onLongPress,
    this.showShadow = true,
  });

  bool get _isDone => task.completedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = _isDone ? 0.6 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              AppHaptics.tap();
              onTap?.call();
            },
            onLongPress: () {
              AppHaptics.tap();
              onLongPress?.call();
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Checkbox
                      _AnimatedCheckbox(
                        isChecked: _isDone,
                        onTap: onComplete,
                      ),

                      // Task content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              task.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration:
                                    _isDone ? TextDecoration.lineThrough : null,
                                color: _isDone
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Subtitle row
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (task.project != null && task.project!.isNotEmpty)
                                  _ProjectChip(name: task.project!),
                                if (task.dueDate != null)
                                  DueDateChip(
                                    date: task.dueDate!,
                                    isCompleted: _isDone,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Priority badge
                      PriorityBadge(priority: task.priority, showLabel: false),
                    ],
                  ),
                ),
                // Priority left border + gradient bleed for high priority (DESIGN_04)
                if (!_isDone) ...[
                  // Solid/gradient priority bar on left edge
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: task.priority == Priority.high
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFF4D4D),
                                  Color(0xFFFF0000),
                                ],
                              )
                            : null,
                        color: task.priority != Priority.high
                            ? _priorityColor
                            : null,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Subtle gradient bleed into card surface for high-priority tasks
                  if (task.priority == Priority.high)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0x1AFF0000),
                              Color(0x00FF0000),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
                  // Gesture discoverability chevrons (DESIGN_10)
                  // Left chevron hint
                  Positioned(
                    left: AppSpacing.sm,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Right chevron hint
                  Positioned(
                    right: AppSpacing.sm,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _priorityColor {
    return switch (task.priority) {
      Priority.high => const Color(0xFFFF4D4D),
      Priority.medium => const Color(0xFFFFB74D),
      _ => const Color(0xFF4FC3F7),
    };
  }
}

/// Animated checkbox for task completion.
class _AnimatedCheckbox extends StatelessWidget {
  final bool isChecked;
  final VoidCallback? onTap;

  const _AnimatedCheckbox({
    required this.isChecked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.complete();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isChecked ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isChecked ? 0 : 2,
          ),
          color: isChecked ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: isChecked
              ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary, key: const ValueKey('checked'))
              : const SizedBox(key: ValueKey('unchecked')),
        ),
      ),
    );
  }
}

/// Project chip for task cards.
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
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_rounded,
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

/// AppButton — styled button variants.
enum ButtonVariant { filled, outlined, text, tonal }

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final bool isLoading;
  final ButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isFullWidth = false,
    this.isLoading = false,
    this.variant = ButtonVariant.filled,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      ButtonVariant.filled => FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      ButtonVariant.outlined => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      ButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      ButtonVariant.tonal => FilledButton.tonal(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
    };

    return isFullWidth
        ? SizedBox(
            width: double.infinity,
            child: button,
          )
        : button;
  }
}

/// Voice-first FAB with pulsing glow animation.
class PulsingMicFab extends StatefulWidget {
  final VoidCallback onPressed;

  const PulsingMicFab({super.key, required this.onPressed});

  @override
  State<PulsingMicFab> createState() => _PulsingMicFabState();
}

class _PulsingMicFabState extends State<PulsingMicFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.reverse();
  void _onTapUp(TapUpDetails _) {
    _scaleController.forward();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3 + (0.2 * _pulseAnimation.value),
                ),
                blurRadius: 16 + (8 * _pulseAnimation.value),
                spreadRadius: 2 + (2 * _pulseAnimation.value),
              ),
            ],
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: widget.onPressed,
            icon: const Icon(Icons.mic),
            label: const Text('Record'),
          ),
        ),
      ),
    );
  }
}

/// Enhanced empty state widget with icon, title, subtitle, and optional action.
class PolishedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double? iconSize;
  final Color? iconColor;

  const PolishedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize ?? 48,
                color: iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer/skeleton loading placeholder.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnimation.value, 0),
              end: Alignment(_shimmerAnimation.value - 1, 0),
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Task list skeleton — shown during initial load.
class TaskListSkeleton extends StatelessWidget {
  const TaskListSkeleton({super.key});

  static const int itemCount = 5;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ShimmerLoading(width: 22, height: 22, borderRadius: BorderRadius.all(Radius.circular(11))),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading(
                      width: double.infinity,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ShimmerLoading(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Gesture hint overlay — shown on first app launch to teach swipe gestures.
/// Uses SharedPreferences to track whether hints have been seen.
/// Usage: Wrap your home screen with [GestureHintOverlay] or call
/// [GestureHintOverlay.showIfNeeded] from your app's init.
class GestureHintOverlay extends StatefulWidget {
  final Widget child;

  const GestureHintOverlay({super.key, required this.child});

  @override
  State<GestureHintOverlay> createState() => _GestureHintOverlayState();

  /// Check if gesture hints should be shown and display a SnackBar if needed.
  /// Call this from your app's initState or main() after initialization.
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('gesture_hints_seen') ?? false;
    if (!context.mounted) return;
    if (!seen) {
      await _showHint(context);
      await prefs.setBool('gesture_hints_seen', true);
    }
  }

  static Future<void> _showHint(BuildContext context) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.swipe, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Swipe right to complete, left to delete',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'GOT IT',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

class _GestureHintOverlayState extends State<GestureHintOverlay> {
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('gesture_hints_seen') ?? false;
    if (mounted && !seen) {
      setState(() => _showOverlay = true);
      // Auto-dismiss after a few seconds
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() => _showOverlay = false);
        await prefs.setBool('gesture_hints_seen', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 100,
          child: Material(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 32,
                            color: Colors.green.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Complete',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 24,
                        color: Colors.white54,
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 32,
                            color: Colors.red.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Swipe tasks to manage them',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
