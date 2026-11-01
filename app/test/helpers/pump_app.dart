import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/theme/app_theme.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside the app theme and localizations.
  Future<void> pumpLocalized(
    Widget widget, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) => pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: widget,
      ),
    ),
  );
}
