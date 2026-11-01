import 'package:flutter/material.dart';
import 'package:offtopic/core/theme/app_colors.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';

/// The single, dark, high-contrast theme of the app.
abstract final class AppTheme {
  static const _buttonTextSize = 20.0;
  static const _minButtonSize = Size(
    AppDimensions.minTapTarget,
    AppDimensions.minTapTarget,
  );
  static const _buttonPadding = EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingLarge,
  );
  static const _buttonTextStyle = TextStyle(
    fontSize: _buttonTextSize,
    fontWeight: FontWeight.w700,
  );

  /// Builds the theme.
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: _buttonPadding,
          textStyle: _buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: _buttonPadding,
          textStyle: _buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: _buttonPadding,
          textStyle: _buttonTextStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: _minButtonSize),
      ),
    );
  }
}
