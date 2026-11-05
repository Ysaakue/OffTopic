import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/room/presentation/controllers/session_report_controller.dart';
import 'package:offtopic/features/room/presentation/widgets/copy_report_button.dart';
import 'package:offtopic/features/room/room_providers.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/room_fixtures.dart';

void main() {
  final started = DateTime(2026, 11, 4, 20);
  late List<String> copied;

  setUp(() {
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pumpButton(WidgetTester tester, SessionReport? report) =>
      tester.pumpLocalized(
        Scaffold(body: CopyReportButton(key: UniqueKey())),
        overrides: [
          sessionReportControllerProvider.overrideWith(
            () => _FixedReport(report),
          ),
          clockProvider.overrideWithValue(() => started),
        ],
      );

  testWidgets('stays hidden before the first room', (tester) async {
    await pumpButton(tester, null);

    expect(find.byKey(const Key('audioTest.copyReport')), findsNothing);
  });

  testWidgets('copies the report and says so', (tester) async {
    await pumpButton(
      tester,
      SessionReport(
        request: joinRequest,
        talk: defaultTalk,
        startedAt: started,
      ),
    );

    await tester.tap(find.text('Copy report'));
    await tester.pump();

    expect(copied.single, startsWith('OffTopic room report\n'));
    expect(
      find.text('Report copied: paste it in the chat with the developers.'),
      findsOneWidget,
    );
  });
}

final class _FixedReport extends SessionReportController {
  new(this._report);

  final SessionReport? _report;

  @override
  SessionReport? build() => _report;
}
