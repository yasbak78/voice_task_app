/// Spacing scale for the Voice Task App design system.
/// NO magic numbers — everything references these constants.
abstract final class AppSpacing {
  /// 4px — Tight spacing (icon gaps, badge padding)
  static const double xs = 4;

  /// 8px — Small spacing (chip gaps, tight margins)
  static const double sm = 8;

  /// 12px — Medium-small spacing (card inner padding)
  static const double md = 12;

  /// 16px — Standard spacing (card padding, section gaps)
  static const double lg = 16;

  /// 20px — Large spacing (section dividers)
  static const double xl = 20;

  /// 24px — Extra-large spacing (screen padding, major sections)
  static const double xxl = 24;

  /// 32px — Section headers, major gaps
  static const double xxxl = 32;

  /// 48px — Huge spacing (hero elements, screen edges)
  static const double huge = 48;

  // Border radius tokens (separate from spacing scale for clarity)
  /// 2px — Subtle corner rounding (accent bars, inline elements)
  static const double radiusSm = 2;
  /// 8px — Small border radius (chips, inline inputs)
  static const double radiusMd = 8;
  /// 12px — Standard border radius (cards, buttons, dialogs)
  static const double radiusLg = 12;
  /// 16px — Large border radius (hero cards, sheets)
  static const double radiusXl = 16;
  /// 20px — Extra-large border radius (pill-shaped elements)
  static const double radiusXxl = 20;
}
