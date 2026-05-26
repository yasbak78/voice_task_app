import 'package:flutter/material.dart';
import 'theme_model.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// All available themes for the Voice Task App.
/// Three curated palettes: Morning Mist, Soft Coral, Sage.
/// Each supports both light and dark mode.
abstract final class AppThemes {
  /// Brand accent colors — consistent across all themes.
  /// Primary: vibrant professional blue.
  static const Color brandPrimary = Color(0xFF2563EB);
  /// Secondary: warm amber for priority/highlights.
  static const Color brandSecondary = Color(0xFFFFB74D);

  /// Shimmer color used for skeleton loading states.
  static const shimmerColor = Color(0xFFE0E0E0);

  /// Theme 1: Morning Mist — cool blue tones (#4A6FA5 primary)
  static const ThemeModel morningMist = ThemeModel(
    id: 'morning_mist',
    name: 'Morning Mist',
    seedColor: Color(0xFF4A6FA5),
    surfaceColor: Color(0xFFFAFBFC),
    darkSurfaceColor: Color(0xFF0F1419),
    accentColor: Color(0xFF5B9BD5),
    icon: Icons.wb_sunny_outlined,
    priorityHigh: Color(0xFFE53935),
    priorityMedium: Color(0xFFF59E0B),
    priorityLow: Color(0xFF4A6FA5),
  );

  /// Theme 2: Soft Coral — warm coral tones (#E8836B accent)
  static const ThemeModel softCoral = ThemeModel(
    id: 'soft_coral',
    name: 'Soft Coral',
    seedColor: Color(0xFFE8836B),
    surfaceColor: Color(0xFFFFF8F5),
    darkSurfaceColor: Color(0xFF1A1210),
    accentColor: Color(0xFF4ECDC4),
    icon: Icons.water_drop_outlined,
    priorityHigh: Color(0xFFE8836B),
    priorityMedium: Color(0xFFF59E0B),
    priorityLow: Color(0xFF4ECDC4),
  );

  /// Theme 3: Sage Paper — earthy green tones (#7BAE7F)
  static const ThemeModel sagePaper = ThemeModel(
    id: 'sage_paper',
    name: 'Sage',
    seedColor: Color(0xFF7BAE7F),
    surfaceColor: Color(0xFFFBF8F3),
    darkSurfaceColor: Color(0xFF121A12),
    accentColor: Color(0xFFD4A574),
    icon: Icons.park_outlined,
    priorityHigh: Color(0xFFDC2626),
    priorityMedium: Color(0xFFD97706),
    priorityLow: Color(0xFF7BAE7F),
  );

  /// Complete list of all available themes.
  static const List<ThemeModel> all = [morningMist, softCoral, sagePaper];

  /// Default theme used when no preference is saved.
  static const ThemeModel defaultTheme = morningMist;

  /// Look up a ThemeModel by its ID. Returns default if not found.
  static ThemeModel byId(String? id) {
    if (id == null) return defaultTheme;
    return all.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
  }

  /// Build a full ThemeData from a ThemeModel and brightness.
  static ThemeData buildThemeData(ThemeModel model, {Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final scheme = model.buildColorScheme(brightness: brightness);
    final onSurfaceColor = isDark
        ? _getOnSurfaceColorDark(model.id)
        : _getOnSurfaceColor(model.id);
    final surface = isDark ? model.darkSurfaceColor : model.surfaceColor;
    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      textTheme: AppTypography.base,
      scaffoldBackgroundColor: surface,
      primaryColor: model.seedColor,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: onSurfaceColor,
        ),
        iconTheme: IconThemeData(color: onSurfaceColor),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A000000),
      ),

      // Card theme — soft elevation, rounded corners (M3 style)
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0x0A000000),
            width: 0.5,
          ),
        ),
        color: surface,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // FAB theme — extended, rounded
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.base.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        labelStyle: AppTypography.base.labelMedium,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHighest,
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: scheme.surfaceContainerHighest,
        selectedTileColor: scheme.primaryContainer,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outline,
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        elevation: 4,
        modalBackgroundColor: surface,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        titleTextStyle: AppTypography.base.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: onSurfaceColor,
        ),
        contentTextStyle: AppTypography.base.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF323232),
        contentTextStyle: AppTypography.base.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF323232) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Icon theme
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 24,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: BorderSide(color: scheme.outline, width: 2),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return null;
        }),
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.base.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.base.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
      ),

      // Segmented button theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
        ),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static Color _getOnSurfaceColor(String themeId) {
    return switch (themeId) {
      'morning_mist' => const Color(0xFF1E293B),
      'soft_coral'   => const Color(0xFF1A1A2E),
      'sage_paper'   => const Color(0xFF1C1917),
      _              => const Color(0xFF1E293B),
    };
  }

  /// On-surface text color for dark mode (light text on dark backgrounds).
  static Color _getOnSurfaceColorDark(String themeId) {
    return switch (themeId) {
      'morning_mist' => const Color(0xFFE2E8F0),
      'soft_coral'   => const Color(0xFFF5F0EB),
      'sage_paper'   => const Color(0xFFEBE7DF),
      _              => const Color(0xFFE2E8F0),
    };
  }
}
