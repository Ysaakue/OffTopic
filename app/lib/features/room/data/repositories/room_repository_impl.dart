import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/voice_platform.dart' as platform;

/// [RoomRepository] over the platform service (lifecycle, owned by Kotlin)
/// and the native core (statistics and events, read through FFI).
final class RoomRepositoryImpl implements RoomRepository {
  const new({required this._rooms, required this._core});

  final platform.RoomServiceControl _rooms;
  final VoiceCoreClient _core;

  @override
  Future<Result<void>> start(RoomRequest request) async {
    try {
      await _rooms.startRoom(_configFor(request, _core.defaults));
      return const Success(null);
    } on platform.VoicePlatformException catch (exception) {
      return Failure(_roomFailure(exception));
    } on VoiceCoreException catch (exception) {
      return Failure(CoreFailure(exception.message));
    }
  }

  @override
  Future<Result<void>> stop() async {
    try {
      await _rooms.stopRoom();
      return const Success(null);
    } on platform.VoicePlatformException catch (exception) {
      return Failure(_roomFailure(exception));
    }
  }

  @override
  Result<SessionStats?> readStats() {
    try {
      final stats = _core.readStats();
      return Success(stats == null ? null : _toEntity(stats));
    } on VoiceCoreException catch (exception) {
      return Failure(CoreFailure(exception.message));
    }
  }

  @override
  Stream<RoomLink> watchLink() => _core.events
      // An undecodable event carries nothing the room screen can show.
      .handleError((Object _) {}, test: (error) => error is VoiceCoreException)
      .expand(
        (event) => switch (event) {
          CoreLinkChanged(:final up, :final peer) => [
            RoomLink(up: up, peer: peer),
          ],
          CoreStateChanged() => const <RoomLink>[],
        },
      );

  /// Ports and bitrate come from the core's defaults: one configuration.
  static platform.RoomConfig _configFor(
    RoomRequest request,
    CoreDefaults defaults,
  ) => switch (request) {
    HostRoomRequest(:final name, :final echoMode) => platform.RoomConfig(
      role: platform.RoomRole.host,
      displayName: name.value,
      controlPort: defaults.controlPort,
      audioPort: defaults.audioPort,
      bitrateBps: defaults.bitrateBps,
      echoMode: echoMode,
    ),
    JoinRoomRequest(:final name, :final host) => platform.RoomConfig(
      role: platform.RoomRole.client,
      hostIp: host.value,
      displayName: name.value,
      controlPort: defaults.controlPort,
      audioPort: defaults.audioPort,
      bitrateBps: defaults.bitrateBps,
    ),
  };

  static RoomFailure _roomFailure(platform.VoicePlatformException exception) {
    final reason = switch (exception.code) {
      platform.VoicePlatformErrorCode.roomAlreadyActive =>
        RoomFailureReason.alreadyActive,
      platform.VoicePlatformErrorCode.invalidConfig =>
        RoomFailureReason.invalidConfig,
      platform.VoicePlatformErrorCode.audioDeviceError =>
        RoomFailureReason.audioDevice,
      platform.VoicePlatformErrorCode.networkError => RoomFailureReason.network,
      _ => RoomFailureReason.unavailable,
    };
    return RoomFailure(reason, exception.message ?? exception.code);
  }

  static SessionStats _toEntity(CoreStats stats) => SessionStats(
    participants: stats.participants,
    lossPct: stats.lossPct,
    jitterMs: stats.jitterMs,
    jitterBufferMs: stats.jitterBufferMs,
    jitterTargetMs: stats.jitterTargetMs,
    rttMs: stats.rttMs,
    inputLevel: stats.inputLevel,
    packetsSent: stats.packetsSent,
    packetsReceived: stats.packetsReceived,
    packetsLost: stats.packetsLost,
    packetsLate: stats.packetsLate,
    fecRecovered: stats.fecRecovered,
    concealedFrames: stats.concealedFrames,
    playoutUnderruns: stats.playoutUnderruns,
  );
}
