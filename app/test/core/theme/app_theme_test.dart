import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/theme/app_colors.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/core/theme/app_theme.dart';

void main() {
  final theme = AppTheme.dark();

  test('is dark with a black background', () {
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  test('text on the main surfaces reaches WCAG AAA contrast (7:1)', () {
    double contrast(Color a, Color b) {
      final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
      final darker = identical(lighter, a) ? b : a;
      return (lighter.computeLuminance() + 0.05) /
          (darker.computeLuminance() + 0.05);
    }

    const aaa = 7.0;
    expect(
      contrast(AppColors.onSurface, AppColors.background),
      greaterThan(aaa),
    );
    expect(contrast(AppColors.onSurface, AppColors.surface), greaterThan(aaa));
    expect(
      contrast(AppColors.onSurfaceVariant, AppColors.surface),
      greaterThan(aaa),
    );
    expect(contrast(AppColors.onPrimary, AppColors.primary), greaterThan(aaa));
    expect(contrast(AppColors.onError, AppColors.error), greaterThan(aaa / 2));
  });

  test('every button type is at least 64 x 64 dp', () {
    const minimum = Size(
      AppDimensions.minTapTarget,
      AppDimensions.minTapTarget,
    );
    final styles = <ButtonStyle?>[
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
      theme.iconButtonTheme.style,
    ];

    for (final style in styles) {
      expect(style?.minimumSize?.resolve({}), minimum);
    }
  });

  testWidgets('a themed FilledButton renders at least 64 dp tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Go')),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(AppDimensions.minTapTarget));
    expect(size.width, greaterThanOrEqualTo(AppDimensions.minTapTarget));
  });
}
