import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:offtopic/features/settings/presentation/widgets/talk_settings_panel.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';

import '../../../../helpers/fake_key_value_store.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late FakeKeyValueStore store;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
    store = FakeKeyValueStore();
  });

  tearDown(() => unawaited(platform.dispose()));

  Future<void> pumpPanel(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpLocalized(
      Scaffold(body: TalkSettingsPanel(key: UniqueKey())),
      locale: locale ?? const Locale('en'),
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
        keyValueStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers the talk modes and the voice sensitivity', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('Talk mode'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Push to talk'), findsOneWidget);
    expect(find.text('Voice detection'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.byKey(const Key('talk.saveFailed')), findsNothing);
  });

  testWidgets('push to talk hides the voice sensitivity', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Push to talk'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('talk.sensitivity')), findsNothing);
    expect(core.talkModes, [CoreTalkMode.pushToTalk]);
  });

  testWidgets('changes the sensitivity', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(core.vadSensitivities, [CoreVadSensitivity.high]);
    expect(store.values[SettingsRepositoryImpl.vadSensitivityKey], 'high');
  });

  testWidgets('warns when a setting could not be saved', (tester) async {
    store.writeError = Exception('disk full');
    await pumpPanel(tester);

    await tester.tap(find.text('Low'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('talk.saveFailed')), findsOneWidget);
  });

  testWidgets('speaks Portuguese', (tester) async {
    await pumpPanel(tester, locale: const Locale('pt'));

    expect(find.text('Modo de fala'), findsOneWidget);
    expect(find.text('Apertar para falar'), findsOneWidget);
  });

  testWidgets('meets the tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPanel(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
