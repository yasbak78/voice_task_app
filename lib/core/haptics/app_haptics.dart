import 'package:flutter/services.dart';

/// Centralized haptic feedback definitions for Voice Task App.
/// Replaces direct HapticFeedback.* calls with semantic, named methods.
///
/// Usage:
///   AppHaptics.tap()       // Light tap on buttons, chips, toggles
///   AppHaptics.complete()  // Task completion, success confirmation
///   AppHaptics.delete()    // Destructive actions, swipe-to-delete
///   AppHaptics.navigate()  // Tab switches, nav transitions
///   AppHaptics.record()    // Recording start/stop
abstract final class AppHaptics {
  /// Light tap — buttons, chips, toggles, filter selection
  static void tap() => HapticFeedback.lightImpact();

  /// Medium impact — task complete, save, FAB press
  static void complete() => HapticFeedback.mediumImpact();

  /// Heavy impact — delete, destructive actions
  static void delete() => HapticFeedback.heavyImpact();

  /// Subtle click — tab switches, navigation, segmented buttons
  static void navigate() => HapticFeedback.selectionClick();

  /// Recording start/stop feedback
  static void record() => HapticFeedback.lightImpact();
}
