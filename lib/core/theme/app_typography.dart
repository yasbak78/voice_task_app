import 'package:flutter/material.dart';

/// Typography scale and custom text styles for the Voice Task App.
/// Uses Inter font family with M3 defaults refined weights and letter spacing.
abstract final class AppTypography {
  // Base text theme (Inter font family, M3 defaults refined)
  static const TextTheme base = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 57,
      height: 64 / 57,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );

  /// Named style: Task title (used in cards and lists)
  static TextStyle taskTitle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Named style: Section header (Today, This Week, etc.)
  static TextStyle sectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );
  }

  /// Named style: Meta info (dates, project tags)
  static TextStyle meta(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Named style: Badge/chip text
  static TextStyle badge(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  /// Named style: Timer display on record screen
  static TextStyle timer(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: theme.textTheme.displayLarge!.fontSize,
      height: theme.textTheme.displayLarge!.height,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w300,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Named style: Quote/callout for transcription
  static TextStyle quote(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge!.copyWith(
      fontStyle: FontStyle.italic,
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
  }
}
