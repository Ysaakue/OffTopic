import 'dart:async';

import 'package:voice_platform/src/models/active_room.dart';
import 'package:voice_platform/src/models/platform_capabilities.dart';
import 'package:voice_platform/src/models/platform_info.dart';
import 'package:voice_platform/src/models/platform_state.dart';
import 'package:voice_platform/src/models/room_config.dart';
import 'package:voice_platform/src/voice_platform_exception.dart';
import 'package:voice_platform/src/voice_platform_gateway.dart';

/// Names of the [VoicePlatformGateway] calls, used to arrange failures.
enum PlatformCall {
  /// [VoicePlatformGateway.getPlatformInfo].
  getPlatformInfo,

  /// [VoicePlatformGateway.startRoom].
  startRoom,

  /// [VoicePlatformGateway.stopRoom].
  stopRoom,

  /// [VoicePlatformGateway.setMute].
  setMute,

  /// [VoicePlatformGateway.getActiveRoom].
  getActiveRoom,

  /// [VoicePlatformGateway.openHotspotSettings].
  openHotspotSettings,

  /// [VoicePlatformGateway.requestBatteryExemption].
  requestBatteryExemption,

  /// [VoicePlatformGateway.setKeepScreenOn].
  setKeepScreenOn,
}

/// In-memory [VoicePlatformGateway] for tests.
///
/// It honors the same contract as the Pigeon gateway (see
/// test/contracts/voice_platform_gateway_contract.dart in this package).
final class FakeVoicePlatformGateway implements VoicePlatformGateway {
  /// Creates a fake that looks like an Android 17 phone by default.
  new({
    this.platformInfo = defaultPlatformInfo,
    this.activeRoom,
    this.batteryExempt = false,
  });

  /// An Android 17 phone with every capability.
  static const defaultPlatformInfo = PlatformInfo(
    osName: 'android',
    osVersion: '17',
    apiLevel: 37,
    manufacturer: 'Google',
    model: 'Pixel 7',
    capabilities: PlatformCapabilities(
      canHostRoom: true,
      supportsGatewayDiscovery: true,
      supportsHotspotSettings: true,
      supportsBatteryExemption: true,
    ),
  );

  /// Value returned by [getPlatformInfo].
  PlatformInfo platformInfo;

  /// Value returned by [getActiveRoom]; updated by [startRoom] and [stopRoom].
  ActiveRoom? activeRoom;

  /// Value returned by [requestBatteryExemption].
  bool batteryExempt;

  /// Last value passed to [setKeepScreenOn].
  bool? keepScreenOn;

  /// Number of [openHotspotSettings] calls.
  int hotspotSettingsOpened = 0;

  /// Every call made, in order.
  final List<PlatformCall> calls = [];

  final Map<PlatformCall, VoicePlatformException> _failures = {};
  final Map<PlatformCall, Future<void>> _holds = {};
  final StreamController<PlatformState> _states =
      StreamController<PlatformState>.broadcast();
  PlatformState _currentState = PlatformState.idle;

  /// Makes [call] throw [error] until [clearFailure] is called.
  void failWith(PlatformCall call, VoicePlatformException error) =>
      _failures[call] = error;

  /// Makes [call] succeed again.
  void clearFailure(PlatformCall call) => _failures.remove(call);

  /// Makes the next [call] wait for [until] before answering, like a slow
  /// platform.
  void holdUntil(PlatformCall call, Future<void> until) => _holds[call] = until;

  /// Publishes a new platform state to the listeners.
  void emitState(PlatformState state) {
    _currentState = state;
    _states.add(state);
  }

  /// Publishes an error to the state listeners.
  void emitStateError(VoicePlatformException error) => _states.addError(error);

  /// Closes the state stream.
  Future<void> dispose() => _states.close();

  @override
  Future<PlatformInfo> getPlatformInfo() async {
    await _enter(PlatformCall.getPlatformInfo);
    return platformInfo;
  }

  @override
  Future<void> startRoom(RoomConfig config) async {
    await _enter(PlatformCall.startRoom);
    activeRoom = ActiveRoom(config: config, muted: false);
  }

  @override
  Future<void> stopRoom() async {
    await _enter(PlatformCall.stopRoom);
    activeRoom = null;
  }

  @override
  Future<void> setMute({required bool muted}) async {
    await _enter(PlatformCall.setMute);
    final room = activeRoom;
    if (room != null) {
      activeRoom = ActiveRoom(config: room.config, muted: muted);
    }
  }

  @override
  Future<ActiveRoom?> getActiveRoom() async {
    await _enter(PlatformCall.getActiveRoom);
    return activeRoom;
  }

  @override
  Future<void> openHotspotSettings() async {
    await _enter(PlatformCall.openHotspotSettings);
    hotspotSettingsOpened++;
  }

  @override
  Future<bool> requestBatteryExemption() async {
    await _enter(PlatformCall.requestBatteryExemption);
    return batteryExempt;
  }

  @override
  Future<void> setKeepScreenOn({required bool enabled}) async {
    await _enter(PlatformCall.setKeepScreenOn);
    keepScreenOn = enabled;
  }

  @override
  Stream<PlatformState> watchPlatformState() async* {
    yield _currentState;
    yield* _states.stream;
  }

  Future<void> _enter(PlatformCall call) async {
    calls.add(call);
    final hold = _holds.remove(call);
    if (hold != null) {
      await hold;
    }
    final failure = _failures[call];
    if (failure != null) {
      throw failure;
    }
  }
}
