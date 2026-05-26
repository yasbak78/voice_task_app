import 'package:flutter/material.dart';
import 'app_themes.dart';

/// Legacy theme configuration — DEPRECATED.
///
/// This file is kept for backward compatibility with existing imports.
/// New code should use `AppThemes.buildThemeData(themeModel)` directly.
///
/// The light theme now uses `AppThemes.defaultTheme` (Morning Mist).
/// The dark theme is no longer supported — the app is light-only.
abstract final class AppTheme {
  @Deprecated('Use AppThemes.buildThemeData(AppThemes.defaultTheme)')
  static ThemeData get lightTheme => AppThemes.buildThemeData(AppThemes.defaultTheme);

  @Deprecated('Dark theme is no longer supported. Use AppThemes.buildThemeData() with a light ThemeModel.')
  static ThemeData get darkTheme => AppThemes.buildThemeData(AppThemes.defaultTheme);
}
