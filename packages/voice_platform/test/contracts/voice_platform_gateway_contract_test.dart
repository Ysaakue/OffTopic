import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../support/mock_host_api.dart';
import 'voice_platform_gateway_contract.dart';

void main() {
  setUpAll(registerHostApiFallbacks);

  voicePlatformGatewayContract(
    'PigeonVoicePlatformGateway',
    _PigeonHarness.new,
  );
  voicePlatformGatewayContract('FakeVoicePlatformGateway', _FakeHarness.new);
}

/// Drives the Pigeon gateway through a mocked host API, mimicking the Kotlin
/// host, whose state stream starts with the idle state
/// (PlatformStateStreamHandler).
final class _PigeonHarness implements VoicePlatformGatewayHarness {
  new() {
    stubHostApiSuccess(_hostApi);
  }

  final _hostApi = MockVoicePlatformHostApi();
  final List<StreamController<PlatformStateMessage>> _streams = [];

  @override
  late final VoicePlatformGateway gateway = PigeonVoicePlatformGateway(
    hostApi: _hostApi,
    platformStates: _openStateStream,
  );

  Stream<PlatformStateMessage> _openStateStream() {
    late final StreamController<PlatformStateMessage> controller;
    controller = StreamController<PlatformStateMessage>(
      onListen: () =>
          controller.add(platformStateMessageFor(PlatformState.idle)),
    );
    _streams.add(controller);
    return controller.stream;
  }

  @override
  void arrangePlatformInfo(PlatformInfo info) {
    when(_hostApi.getPlatformInfo)
        .thenAnswer((_) async => platformInfoMessageFor(info));
  }

  @override
  void arrangeActiveRoom(ActiveRoom room) {
    when(_hostApi.getActiveRoom)
        .thenAnswer((_) async => activeRoomMessageFor(room));
  }

  @override
  void arrangeBatteryExempt({required bool exempt}) {
    when(_hostApi.requestBatteryExemption).thenAnswer((_) async => exempt);
  }

  @override
  void arrangeFailure(PlatformCall call, String code) {
    final error = PlatformException(code: code);
    switch (call) {
      case PlatformCall.getPlatformInfo:
        when(_hostApi.getPlatformInfo).thenThrow(error);
      case PlatformCall.startRoom:
        when(() => _hostApi.startRoom(any())).thenThrow(error);
      case PlatformCall.stopRoom:
        when(_hostApi.stopRoom).thenThrow(error);
      case PlatformCall.setMute:
        when(() => _hostApi.setMute(any())).thenThrow(error);
      case PlatformCall.getActiveRoom:
        when(_hostApi.getActiveRoom).thenThrow(error);
      case PlatformCall.openHotspotSettings:
        when(_hostApi.openHotspotSettings).thenThrow(error);
      case PlatformCall.requestBatteryExemption:
        when(_hostApi.requestBatteryExemption).thenThrow(error);
      case PlatformCall.setKeepScreenOn:
        when(() => _hostApi.setKeepScreenOn(any())).thenThrow(error);
    }
  }

  @override
  void emitState(PlatformState state) {
    for (final stream in _streams) {
      stream.add(platformStateMessageFor(state));
    }
  }

  @override
  void emitStateFailure(String code) {
    for (final stream in _streams) {
      stream.addError(PlatformException(code: code));
    }
  }

  @override
  Future<void> dispose() async {
    // close() never completes for a stream nobody listened to, so do not wait.
    for (final stream in _streams) {
      unawaited(stream.close());
    }
  }
}

final class _FakeHarness implements VoicePlatformGatewayHarness {
  final _fake = FakeVoicePlatformGateway();

  @override
  VoicePlatformGateway get gateway => _fake;

  @override
  void arrangePlatformInfo(PlatformInfo info) => _fake.platformInfo = info;

  @override
  void arrangeActiveRoom(ActiveRoom room) => _fake.activeRoom = room;

  @override
  void arrangeBatteryExempt({required bool exempt}) =>
      _fake.batteryExempt = exempt;

  @override
  void arrangeFailure(PlatformCall call, String code) =>
      _fake.failWith(call, VoicePlatformException(code: code));

  @override
  void emitState(PlatformState state) => _fake.emitState(state);

  @override
  void emitStateFailure(String code) =>
      _fake.emitStateError(VoicePlatformException(code: code));

  @override
  Future<void> dispose() => _fake.dispose();
}
