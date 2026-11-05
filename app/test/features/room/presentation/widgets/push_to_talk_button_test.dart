import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/room/presentation/widgets/push_to_talk_button.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  late List<bool> changes;

  setUp(() => changes = []);

  Future<void> pumpButton(WidgetTester tester) => tester.pumpLocalized(
    Scaffold(
      body: PushToTalkButton(key: UniqueKey(), onChanged: changes.add),
    ),
  );

  final button = find.byKey(const Key('talk.pushToTalk'));

  testWidgets('is a large area that invites holding', (tester) async {
    await pumpButton(tester);

    expect(find.text('Hold to talk'), findsOneWidget);
    expect(
      tester.getSize(button).height,
      greaterThanOrEqualTo(AppDimensions.pushToTalkHeight),
    );
  });

  testWidgets('talks while held', (tester) async {
    await pumpButton(tester);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(find.text('Talking…'), findsOneWidget);
    expect(changes, [true]);

    await gesture.up();
    await tester.pump();
    expect(find.text('Hold to talk'), findsOneWidget);
    expect(changes, [true, false]);
  });

  testWidgets('stays pressed until the last finger leaves', (tester) async {
    await pumpButton(tester);

    final first = await tester.startGesture(
      tester.getCenter(button),
      pointer: 11,
    );
    final second = await tester.startGesture(
      tester.getCenter(button),
      pointer: 12,
    );
    await first.up();
    expect(changes, [true]);

    await second.up();
    expect(changes, [true, false]);
  });

  testWidgets('a cancelled touch releases it', (tester) async {
    await pumpButton(tester);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await gesture.cancel();

    expect(changes, [true, false]);
  });

  testWidgets('leaving the screen while held releases it', (tester) async {
    await pumpButton(tester);
    await tester.startGesture(tester.getCenter(button));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(changes, [true, false]);
  });

  testWidgets('leaving the screen while released says nothing', (tester) async {
    await pumpButton(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(changes, isEmpty);
  });
}
