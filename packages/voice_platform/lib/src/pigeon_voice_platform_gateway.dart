import 'dart:async';

import 'package:flutter/services.dart';
import 'package:voice_platform/src/generated/voice_platform_api.g.dart' as api;
import 'package:voice_platform/src/message_mappers.dart';
import 'package:voice_platform/src/models/active_room.dart';
import 'package:voice_platform/src/models/platform_info.dart';
import 'package:voice_platform/src/models/platform_state.dart';
import 'package:voice_platform/src/models/room_config.dart';
import 'package:voice_platform/src/voice_platform_exception.dart';
import 'package:voice_platform/src/voice_platform_gateway.dart';

/// Opens the platform state event stream.
typedef PlatformStateStreamFactory =
    Stream<api.PlatformStateMessage> Function();

/// [VoicePlatformGateway] over the Pigeon channels.
final class PigeonVoicePlatformGateway implements VoicePlatformGateway {
  /// Creates the gateway. The parameters exist for tests; production code
  /// uses the generated channels.
  new({
    api.VoicePlatformHostApi? hostApi,
    PlatformStateStreamFactory? platformStates,
  }) : _hostApi = hostApi ?? api.VoicePlatformHostApi(),
       _platformStates = platformStates ?? api.watchPlatformState;

  final api.VoicePlatformHostApi _hostApi;
  final PlatformStateStreamFactory _platformStates;

  @override
  Future<PlatformInfo> getPlatformInfo() =>
      _guard(() async => (await _hostApi.getPlatformInfo()).toModel());

  @override
  Future<void> startRoom(RoomConfig config) =>
      _guard(() => _hostApi.startRoom(config.toMessage()));

  @override
  Future<void> stopRoom() => _guard(_hostApi.stopRoom);

  @override
  Future<void> setMute({required bool muted}) =>
      _guard(() => _hostApi.setMute(muted));

  @override
  Future<ActiveRoom?> getActiveRoom() =>
      _guard(() async => (await _hostApi.getActiveRoom())?.toModel());

  @override
  Future<void> openHotspotSettings() => _guard(_hostApi.openHotspotSettings);

  @override
  Future<bool> requestBatteryExemption() =>
      _guard(_hostApi.requestBatteryExemption);

  @override
  Future<void> setKeepScreenOn({required bool enabled}) =>
      _guard(() => _hostApi.setKeepScreenOn(enabled));

  @override
  Stream<PlatformState> watchPlatformState() => _platformStates()
      .map((message) => message.toModel())
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) => sink.addError(
            error is PlatformException
                ? VoicePlatformException.fromPlatformException(error)
                : error,
            stackTrace,
          ),
        ),
      );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (exception) {
      throw VoicePlatformException.fromPlatformException(exception);
    }
  }
}
