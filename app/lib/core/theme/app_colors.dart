import 'package:flutter/material.dart';

/// High-contrast palette: readable in direct sunlight through a visor.
abstract final class AppColors {
  /// Screen background.
  static const background = Color(0xFF000000);

  /// Cards and sheets.
  static const surface = Color(0xFF121212);

  /// Main actions and highlights.
  static const primary = Color(0xFFFFC107);

  /// Content drawn on [primary].
  static const onPrimary = Color(0xFF000000);

  /// Secondary highlights.
  static const secondary = Color(0xFF4FC3F7);

  /// Content drawn on [secondary].
  static const onSecondary = Color(0xFF000000);

  /// Errors and destructive actions.
  static const error = Color(0xFFFF5252);

  /// Content drawn on [error].
  static const onError = Color(0xFF000000);

  /// Main text and icons.
  static const onSurface = Color(0xFFFFFFFF);

  /// Supporting text.
  static const onSurfaceVariant = Color(0xFFE0E0E0);
}
