import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/features/room/presentation/screens/audio_test_screen.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fake_permission_requester.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/room_fixtures.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late FakePermissionRequester permissions;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
    permissions = FakePermissionRequester();
  });

  tearDown(() => unawaited(platform.dispose()));

  Future<void> pumpScreen(WidgetTester tester, {Locale? locale}) =>
      tester.pumpLocalized(
        // Runtime key: see app_test.dart (coverage of const constructors).
        AudioTestScreen(key: UniqueKey()),
        locale: locale ?? const Locale('en'),
        overrides: [
          voicePlatformGatewayProvider.overrideWithValue(platform),
          voiceCoreClientProvider.overrideWithValue(core),
          permissionRequesterProvider.overrideWithValue(permissions),
        ],
      );

  Future<void> join(WidgetTester tester, String ip) async {
    await tester.enterText(find.byKey(const Key('audioTest.hostIp')), ip);
    await tester.tap(find.byKey(const Key('audioTest.start')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts idle, ready to join', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Audio test'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.byKey(const Key('audioTest.hostIp')), findsOneWidget);
    expect(find.byKey(const Key('audioTest.echo')), findsNothing);
  });

  testWidgets('refuses an invalid host address', (tester) async {
    await pumpScreen(tester);

    await join(tester, '192.168.1');

    expect(
      find.text("Type the host's IPv4 address, e.g. 192.168.43.1."),
      findsOneWidget,
    );
    expect(platform.calls, isNot(contains(PlatformCall.startRoom)));

    await tester.enterText(find.byKey(const Key('audioTest.hostIp')), '1');
    await tester.pump();
    expect(
      find.text("Type the host's IPv4 address, e.g. 192.168.43.1."),
      findsNothing,
    );
  });

  testWidgets('joins a host and shows the live statistics', (tester) async {
    core.stats = sampleCoreStats;
    await pumpScreen(tester);

    await join(tester, ' 192.168.43.1 ');
    await tester.pump(const Duration(milliseconds: 300));

    expect(platform.activeRoom?.config.hostIp, '192.168.43.1');
    expect(platform.activeRoom?.config.role, RoomRole.client);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('1.3 %'), findsOneWidget);
    expect(find.text('3.5 ms'), findsOneWidget);
    expect(find.text('60 ms (target 40 ms)'), findsOneWidget);
    expect(find.text('42 ms'), findsOneWidget);
    expect(find.text('100 / 98'), findsOneWidget);
    expect(find.text('2 / 1'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(const Key('audioTest.inputLevel')), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('Waiting for the other phone…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('audioTest.stop')));
    await tester.pumpAndSettle();
    expect(platform.activeRoom, isNull);
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('shows the link reported by the core', (tester) async {
    core.stats = sampleCoreStats;
    await pumpScreen(tester);
    await join(tester, '192.168.43.1');
    await tester.pump(const Duration(milliseconds: 300));

    core.emitEvent(const CoreLinkChanged(up: true, peer: '192.168.43.1:47801'));
    await _deliverEvent(tester);
    expect(find.text('Connected to 192.168.43.1:47801'), findsOneWidget);

    core.emitEvent(
      const CoreLinkChanged(up: false, peer: '192.168.43.1:47801'),
    );
    await _deliverEvent(tester);
    expect(
      find.text('Connection lost with 192.168.43.1:47801'),
      findsOneWidget,
    );
  });

  testWidgets('shows an unknown round trip as a dash', (tester) async {
    core.stats = const CoreStats(
      participants: 0,
      lossPct: 0,
      jitterMs: 0,
      jitterBufferMs: 0,
      jitterTargetMs: 40,
      inputLevel: 0,
      packetsSent: 0,
      packetsReceived: 0,
      packetsLost: 0,
      packetsLate: 0,
      fecRecovered: 0,
      concealedFrames: 0,
      playoutUnderruns: 0,
      captureOverruns: 0,
    );
    await pumpScreen(tester);
    await join(tester, '192.168.43.1');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('—'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audioTest.stop')));
    await tester.pumpAndSettle();
  });

  testWidgets('hosts with echo mode', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Host'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audioTest.echo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('audioTest.start')));
    await tester.pumpAndSettle();

    expect(platform.activeRoom?.config.role, RoomRole.host);
    expect(platform.activeRoom?.config.echoMode, isTrue);
    await tester.tap(find.byKey(const Key('audioTest.stop')));
    await tester.pumpAndSettle();
  });

  testWidgets('explains a failure in the rider language', (tester) async {
    platform.failWith(
      PlatformCall.startRoom,
      const VoicePlatformException(code: 'network_error'),
    );
    await pumpScreen(tester, locale: const Locale('pt'));

    await join(tester, '192.168.43.1');

    expect(
      find.text('Não foi possível abrir a rede. Confira o Wi-Fi.'),
      findsOneWidget,
    );
    expect(find.text('Parado'), findsOneWidget);
  });

  testWidgets('asks for the settings when a permission is refused for good', (
    tester,
  ) async {
    permissions.statuses[AppPermission.localNetwork] =
        AppPermissionStatus.permanentlyDenied;
    await pumpScreen(tester);

    await join(tester, '192.168.43.1');

    expect(find.byKey(const Key('permissionDenied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('permissionDenied.settings')));
    await tester.pump();
    expect(permissions.settingsOpened, 1);

    await tester.tap(find.byKey(const Key('permissionDenied.retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audioTest.start')), findsOneWidget);
  });

  testWidgets('offers only a retry for a permission refused once', (
    tester,
  ) async {
    permissions.statuses[AppPermission.microphone] = AppPermissionStatus.denied;
    await pumpScreen(tester);

    await join(tester, '192.168.43.1');

    expect(find.byKey(const Key('permissionDenied.settings')), findsNothing);
    expect(find.byKey(const Key('permissionDenied.retry')), findsOneWidget);
  });

  testWidgets('shows progress and locks the form while starting', (
    tester,
  ) async {
    final hold = Completer<void>();
    platform.holdUntil(PlatformCall.startRoom, hold.future);
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('audioTest.hostIp')),
      '192.168.43.1',
    );
    await tester.tap(find.byKey(const Key('audioTest.start')));
    await tester.pump();

    expect(find.text('Starting…'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.byKey(const Key('audioTest.start')),
    );
    expect(start.onPressed, isNull);

    hold.complete();
    await tester.pumpAndSettle();
    final stopHold = Completer<void>();
    platform.holdUntil(PlatformCall.stopRoom, stopHold.future);
    await tester.tap(find.byKey(const Key('audioTest.stop')));
    await tester.pump();
    expect(find.text('Stopping…'), findsOneWidget);
    stopHold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('meets the tap target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(
      tester.getSize(find.byKey(const Key('audioTest.start'))).height,
      greaterThanOrEqualTo(64),
    );
    handle.dispose();
  });
}

/// The event arrives in a microtask; the rebuild happens on the next frame.
Future<void> _deliverEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
