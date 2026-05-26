import 'package:flutter/material.dart';

/// Theme model representing a selectable visual theme.
/// Each theme has a unique ID, display name, icon, and color palette.
class ThemeModel {
  final String id;
  final String name;
  final Color seedColor;
  final Color surfaceColor;
  final Color darkSurfaceColor;
  final Color accentColor;
  final IconData icon;
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;

  const ThemeModel({
    required this.id,
    required this.name,
    required this.seedColor,
    required this.surfaceColor,
    required this.darkSurfaceColor,
    required this.accentColor,
    required this.icon,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
  });

  /// Generate a full Material 3 ColorScheme from this theme's palette.
  ColorScheme buildColorScheme({Brightness brightness = Brightness.light}) {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: brightness == Brightness.dark ? darkSurfaceColor : surfaceColor,
    );
  }
}
