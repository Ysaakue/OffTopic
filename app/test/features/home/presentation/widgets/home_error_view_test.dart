import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/features/home/presentation/widgets/home_error_view.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  Future<void> pumpError(
    WidgetTester tester,
    Object error,
    VoidCallback onRetry,
  ) => tester.pumpLocalized(
    Scaffold(
      body: HomeErrorView(error: error, onRetry: onRetry),
    ),
  );

  testWidgets('platform failures get the phone information message', (
    tester,
  ) async {
    await pumpError(tester, const PlatformFailure(code: 'x'), () {});

    expect(find.text('Could not read the phone information.'), findsOneWidget);
  });

  testWidgets('core failures get the voice core message', (tester) async {
    await pumpError(tester, const CoreFailure('down'), () {});

    expect(find.text('The voice core did not respond.'), findsOneWidget);
  });

  testWidgets('unexpected errors fall back to the voice core message', (
    tester,
  ) async {
    await pumpError(tester, StateError('surprise'), () {});

    expect(find.text('The voice core did not respond.'), findsOneWidget);
  });

  testWidgets('the retry button calls back', (tester) async {
    var retries = 0;
    await pumpError(tester, const CoreFailure('down'), () => retries++);

    await tester.tap(find.text('Try again'));

    expect(retries, 1);
  });
}
