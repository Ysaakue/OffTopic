import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/home/presentation/widgets/app_info_panel.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  AppInfo infoFor(String osName) => AppInfo(
    coreVersion: '0.1.0',
    manufacturer: 'Apple',
    model: 'iPhone 15',
    osName: osName,
    osVersion: '26',
  );

  Future<String> deviceLine(WidgetTester tester, String osName) async {
    await tester.pumpLocalized(
      Scaffold(body: AppInfoPanel(info: infoFor(osName))),
    );
    return tester.widget<Text>(find.byKey(const Key('home.device'))).data!;
  }

  testWidgets('shows Android with its brand capitalization', (tester) async {
    expect(await deviceLine(tester, 'android'), 'Apple iPhone 15 · Android 26');
  });

  testWidgets('shows iOS with its brand capitalization', (tester) async {
    expect(await deviceLine(tester, 'ios'), 'Apple iPhone 15 · iOS 26');
  });

  testWidgets('keeps unknown OS names as reported', (tester) async {
    expect(await deviceLine(tester, 'fuchsia'), 'Apple iPhone 15 · fuchsia 26');
  });
}
