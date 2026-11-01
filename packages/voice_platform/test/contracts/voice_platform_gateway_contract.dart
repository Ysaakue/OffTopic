import 'package:flutter_test/flutter_test.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../support/samples.dart';

/// Arranges a [VoicePlatformGateway] implementation for the contract suite.
abstract interface class VoicePlatformGatewayHarness {
  VoicePlatformGateway get gateway;

  void arrangePlatformInfo(PlatformInfo info);

  void arrangeActiveRoom(ActiveRoom room);

  void arrangeBatteryExempt({required bool exempt});

  void arrangeFailure(PlatformCall call, String code);

  /// Publishes [state] to the gateway's state stream listeners.
  void emitState(PlatformState state);

  /// Publishes a platform failure with [code] to the state stream.
  void emitStateFailure(String code);

  Future<void> dispose();
}

/// Behavior every [VoicePlatformGateway] must share, so that the fake used by
/// the app tests can stand in for the Pigeon gateway (Liskov substitution).
void voicePlatformGatewayContract(
  String implementation,
  VoicePlatformGatewayHarness Function() createHarness,
) {
  group('$implementation honors the VoicePlatformGateway contract:', () {
    late VoicePlatformGatewayHarness harness;

    setUp(() => harness = createHarness());
    tearDown(() => harness.dispose());

    test('returns the platform info the host reports', () async {
      harness.arrangePlatformInfo(samplePlatformInfo);

      expect(await harness.gateway.getPlatformInfo(), samplePlatformInfo);
    });

    test('has no active room until the host reports one', () async {
      expect(await harness.gateway.getActiveRoom(), isNull);

      const room = ActiveRoom(config: sampleClientConfig, muted: true);
      harness.arrangeActiveRoom(room);

      expect(await harness.gateway.getActiveRoom(), room);
    });

    test('returns the battery exemption answer', () async {
      harness.arrangeBatteryExempt(exempt: true);
      expect(await harness.gateway.requestBatteryExemption(), isTrue);

      harness.arrangeBatteryExempt(exempt: false);
      expect(await harness.gateway.requestBatteryExemption(), isFalse);
    });

    test('completes every command the host accepts', () async {
      final gateway = harness.gateway;

      await expectLater(gateway.startRoom(sampleClientConfig), completes);
      await expectLater(gateway.setMute(muted: true), completes);
      await expectLater(gateway.setKeepScreenOn(enabled: true), completes);
      await expectLater(gateway.openHotspotSettings(), completes);
      await expectLater(gateway.stopRoom(), completes);
    });

    for (final call in PlatformCall.values) {
      test('reports a ${call.name} failure as VoicePlatformException', () {
        harness.arrangeFailure(call, 'host_failure');

        expect(
          _invoke(harness.gateway, call),
          throwsA(
            isA<VoicePlatformException>().having(
              (e) => e.code,
              'code',
              'host_failure',
            ),
          ),
        );
      });
    }

    test('starts the state stream with the idle state', () async {
      expect(
        await harness.gateway.watchPlatformState().first,
        PlatformState.idle,
      );
    });

    test('streams every state change in order', () async {
      const running = PlatformState(
        serviceRunning: true,
        audioRoute: AudioRoute.bluetoothHeadset,
        wifiState: WifiState.connected,
      );
      const speaker = PlatformState(
        serviceRunning: true,
        audioRoute: AudioRoute.speaker,
        wifiState: WifiState.connected,
      );
      final states = <PlatformState>[];
      final subscription = harness.gateway.watchPlatformState().listen(
        states.add,
      );
      await pumpEventQueue();

      harness
        ..emitState(running)
        ..emitState(speaker);
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, [PlatformState.idle, running, speaker]);
    });

    test('reports a state stream failure as VoicePlatformException', () async {
      final errors = <Object>[];
      final subscription = harness.gateway.watchPlatformState().listen(
        (_) {},
        onError: errors.add,
      );
      await pumpEventQueue();

      harness.emitStateFailure('route_lost');
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, [
        isA<VoicePlatformException>().having(
          (e) => e.code,
          'code',
          'route_lost',
        ),
      ]);
    });
  });
}

Future<Object?> _invoke(VoicePlatformGateway gateway, PlatformCall call) =>
    switch (call) {
      PlatformCall.getPlatformInfo => gateway.getPlatformInfo(),
      PlatformCall.startRoom => gateway.startRoom(sampleClientConfig),
      PlatformCall.stopRoom => gateway.stopRoom(),
      PlatformCall.setMute => gateway.setMute(muted: true),
      PlatformCall.getActiveRoom => gateway.getActiveRoom(),
      PlatformCall.openHotspotSettings => gateway.openHotspotSettings(),
      PlatformCall.requestBatteryExemption => gateway.requestBatteryExemption(),
      PlatformCall.setKeepScreenOn => gateway.setKeepScreenOn(enabled: true),
    };
