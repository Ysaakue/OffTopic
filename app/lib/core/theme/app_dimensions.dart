/// Sizes shared by every screen. The UI is used at a glance and with gloves.
abstract final class AppDimensions {
  /// Minimum size of anything the rider can tap (spec: at least 64 dp).
  static const double minTapTarget = 64;

  /// Small gap between related items.
  static const double spacingSmall = 8;

  /// Default gap and screen padding.
  static const double spacingMedium = 16;

  /// Gap between sections.
  static const double spacingLarge = 32;

  /// Height of the push-to-talk area: easy to find and hold with gloves.
  static const double pushToTalkHeight = 160;

  /// Corner radius of large touch areas.
  static const double largeRadius = 24;
}
