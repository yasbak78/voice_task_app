import 'package:flutter/material.dart';
import 'app_themes.dart';
import 'theme_model.dart';

/// Semantic color tokens for the Voice Task App design system.
///
/// All colors flow through the active theme — no hardcoded hex colors in widgets.
/// For standard Material 3 colors, use `Theme.of(context).colorScheme.*` directly.
/// Use `AppColors.priority(context, task.priority)` for theme-aware priority colors.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Priority colors — accessed via the active ThemeModel
  // ---------------------------------------------------------------------------

  /// Get the priority color for a given [Priority] using the active theme.
  /// Usage: `AppColors.priority(context, task.priority)`
  static Color priority(BuildContext context, dynamic priority) {
    final themeModel = themeModelFor(context);
    return switch (priority) {
      _ when _isHigh(priority) => themeModel.priorityHigh,
      _ when _isMedium(priority) => themeModel.priorityMedium,
      _ when _isLow(priority) => themeModel.priorityLow,
      _ => themeModel.priorityMedium,
    };
  }

  /// Get a semi-transparent background color for a priority level.
  static Color priorityBg(BuildContext context, dynamic priority, {double alpha = 0.12}) {
    return priority(context, priority).withValues(alpha: alpha);
  }

  // ---------------------------------------------------------------------------
  // Semantic colors — theme-aware accessors
  // ---------------------------------------------------------------------------

  /// Get a theme-aware success/completion color.
  static Color success(BuildContext context) {
    return Theme.of(context).colorScheme.tertiary;
  }

  /// Get a theme-aware info color.
  static Color info(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Get a theme-aware error color.
  static Color error(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  /// Get a theme-aware recording active color (maps to error accent).
  static Color recordingActive(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  /// Get a theme-aware recording processing color (maps to secondary).
  static Color recordingProcessing(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Get a theme-aware recording idle color (maps to onSurfaceVariant).
  static Color recordingIdle(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Get a theme-aware swipe background color for task completion.
  static Color swipeBackground(BuildContext context) {
    return Theme.of(context).colorScheme.tertiary;
  }

  // ---------------------------------------------------------------------------
  // Theme lookup helper
  // ---------------------------------------------------------------------------

  /// Get the current theme model from context.
  static ThemeModel themeModelFor(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    for (final theme in AppThemes.all) {
      if (theme.seedColor == primary) {
        return theme;
      }
    }
    return AppThemes.defaultTheme;
  }

  static bool _isHigh(dynamic p) => p.toString().contains('high');
  static bool _isMedium(dynamic p) => p.toString().contains('medium');
  static bool _isLow(dynamic p) => p.toString().contains('low');

  // ---------------------------------------------------------------------------
  // Legacy compatibility — DEPRECATED, migrate to theme/colorScheme
  // ---------------------------------------------------------------------------

  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static Color get primary => AppThemes.defaultTheme.seedColor;

  @Deprecated('Use AppColors.priority(context, p)')
  static Color get priorityHigh => AppThemes.defaultTheme.priorityHigh;

  @Deprecated('Use AppColors.priority(context, p)')
  static Color get priorityMedium => AppThemes.defaultTheme.priorityMedium;

  @Deprecated('Use AppColors.priority(context, p)')
  static Color get priorityLow => AppThemes.defaultTheme.priorityLow;

  @Deprecated('Use AppColors.error(context)')
  static Color get errorStatic => const Color(0xFFE53935);

  @Deprecated('Use Theme.of(context).colorScheme.shadow')
  static Color get shadow => const Color(0x0A000000);

  @Deprecated('Use Theme.of(context).colorScheme.shadow')
  static Color get shadowDark => const Color(0x1A000000);
}
