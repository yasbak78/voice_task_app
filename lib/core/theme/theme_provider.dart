import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_themes.dart';
import 'theme_model.dart';
import '../../providers/theme_provider.dart';

/// SharedPreferences key for persisting theme preference.
const _kThemeKey = 'selected_theme';

/// Riverpod provider exposing the current theme ID.
/// Watch this to rebuild when the theme changes.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeModel>((ref) {
  return ThemeNotifier();
});

/// Riverpod provider exposing the full ThemeData for the current theme,
/// respecting the current dark/light mode selection.
final themeDataProvider = Provider<ThemeData>((ref) {
  final themeModel = ref.watch(themeProvider);
  final themeMode = ref.watch(themeModeProvider);
  final brightness = themeMode.toThemeMode() == ThemeMode.dark
      ? Brightness.dark
      : themeMode.toThemeMode() == ThemeMode.system
          ? PlatformDispatcher.instance.platformBrightness
          : Brightness.light;
  return AppThemes.buildThemeData(themeModel, brightness: brightness);
});

/// StateNotifier managing the active theme with SharedPreferences persistence.
class ThemeNotifier extends StateNotifier<ThemeModel> {
  ThemeNotifier() : super(AppThemes.defaultTheme) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemeKey);
      state = AppThemes.byId(saved);
    } catch (_) {
      // Silently fail — default theme is already set
    }
  }

  /// Set the active theme by ThemeModel.
  Future<void> setTheme(ThemeModel theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeKey, theme.id);
    } catch (_) {
      // Silently fail — preference won't persist
    }
  }

  /// Cycle to the next available theme.
  Future<void> cycleTheme() async {
    final currentIndex = AppThemes.all.indexWhere((t) => t.id == state.id);
    final nextIndex = (currentIndex + 1) % AppThemes.all.length;
    await setTheme(AppThemes.all[nextIndex]);
  }
}
