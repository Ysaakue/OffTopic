import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/presentation/widgets/talk_status_panel.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
  });

  tearDown(() => unawaited(platform.dispose()));

  Future<void> pumpPanel(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpLocalized(
      Scaffold(body: TalkStatusPanel(key: UniqueKey())),
      locale: locale ?? const Locale('en'),
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
      ],
    );
    await tester.pump();
  }

  Future<void> route(
    WidgetTester tester,
    AudioRoute audioRoute, {
    bool systemCall = false,
  }) async {
    platform.emitState(
      PlatformState(
        serviceRunning: false,
        audioRoute: audioRoute,
        wifiState: WifiState.unknown,
        systemCall: systemCall,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('starts with no route and a quiet microphone', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Audio: not routed yet'), findsOneWidget);
    expect(find.text('Your microphone is quiet'), findsOneWidget);
  });

  testWidgets('names every route', (tester) async {
    await pumpPanel(tester);

    for (final (audioRoute, text) in [
      (AudioRoute.bluetoothHeadset, 'Audio: Intercom (Bluetooth)'),
      (AudioRoute.wiredHeadset, 'Audio: Headset'),
      (AudioRoute.speaker, 'Audio: Loudspeaker'),
      (AudioRoute.earpiece, 'Audio: Earpiece'),
    ]) {
      await route(tester, audioRoute);
      expect(find.text(text), findsOneWidget, reason: audioRoute.name);
    }
  });

  testWidgets('says whether the phone treats the room as a call', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(
      find.text('Direct audio routing (the phone refused the call mode)'),
      findsOneWidget,
    );

    await route(tester, AudioRoute.bluetoothHeadset, systemCall: true);

    expect(
      find.text('Phone call mode: the intercom sees a call'),
      findsOneWidget,
    );
  });

  testWidgets('shows when the microphone is on the air', (tester) async {
    await pumpPanel(tester);

    core.emitEvent(const CoreTalkingChanged(talking: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your microphone is on the air'), findsOneWidget);

    core.emitEvent(const CoreTalkingChanged(talking: false));
    await tester.pump();
    await tester.pump();
    expect(find.text('Your microphone is quiet'), findsOneWidget);
  });

  testWidgets('speaks Portuguese', (tester) async {
    await pumpPanel(tester, locale: const Locale('pt'));
    await route(tester, AudioRoute.bluetoothHeadset);

    expect(find.text('Áudio: Intercomunicador (Bluetooth)'), findsOneWidget);
    expect(find.text('Seu microfone está em silêncio'), findsOneWidget);
  });
}
