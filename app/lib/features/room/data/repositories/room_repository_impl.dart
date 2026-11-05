import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/voice_platform.dart' as platform;

/// [RoomRepository] over the platform service (lifecycle, owned by Kotlin)
/// and the native core (statistics and events, read through FFI).
final class RoomRepositoryImpl implements RoomRepository {
  const new({
    required this._rooms,
    required this._platformState,
    required this._core,
  });

  final platform.RoomServiceControl _rooms;
  final platform.PlatformStateSource _platformState;
  final VoiceCoreClient _core;

  @override
  Future<Result<void>> start(
    RoomRequest request, {
    required TalkSettings talk,
  }) async {
    try {
      await _rooms.startRoom(_configFor(request, _core.defaults, talk));
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
      return Success(stats == null ? null : _toEntity(stats, _core.defaults));
    } on VoiceCoreException catch (exception) {
      return Failure(CoreFailure(exception.message));
    }
  }

  @override
  Result<void> applyTalkSettings(TalkSettings talk) => _control(() {
    _core
      ..setTalkMode(_coreTalkMode(talk.mode))
      ..setVadSensitivity(_coreSensitivity(talk.sensitivity));
  });

  @override
  void setPushToTalk({required bool pressed}) =>
      _core.setPushToTalk(pressed: pressed);

  @override
  Stream<RoomLink> watchLink() => _events.expand(
    (event) => switch (event) {
      CoreLinkChanged(:final up, :final peer) => [RoomLink(up: up, peer: peer)],
      CoreStateChanged() || CoreTalkingChanged() => const <RoomLink>[],
    },
  );

  @override
  Stream<bool> watchTalking() => _events.expand(
    (event) => switch (event) {
      CoreTalkingChanged(:final talking) => [talking],
      CoreStateChanged() || CoreLinkChanged() => const <bool>[],
    },
  );

  @override
  Stream<RoomAudio> watchAudio() => _platformState
      .watchPlatformState()
      // A platform error leaves the last state on screen.
      .handleError(
        (Object _) {},
        test: (error) => error is platform.VoicePlatformException,
      )
      .map(
        (state) => RoomAudio(
          route: _route(state.audioRoute),
          systemCall: state.systemCall,
        ),
      )
      .distinct();

  @override
  Stream<void> watchSessionStopped() => _events
      .where(
        (event) =>
            event is CoreStateChanged && event.state == CoreState.stopped,
      )
      .map((_) {});

  // One way is half the round trip.
  static const _halves = 2;

  // An undecodable event carries nothing the room screen can show.
  Stream<CoreEvent> get _events => _core.events.handleError(
    (Object _) {},
    test: (error) => error is VoiceCoreException,
  );

  static Result<void> _control(void Function() send) {
    try {
      send();
      return const Success(null);
    } on VoiceCoreException catch (exception) {
      return Failure(CoreFailure(exception.message));
    }
  }

  /// Ports and bitrate come from the core's defaults: one configuration.
  static platform.RoomConfig _configFor(
    RoomRequest request,
    CoreDefaults defaults,
    TalkSettings talk,
  ) => switch (request) {
    HostRoomRequest(:final name, :final echoMode) => platform.RoomConfig(
      role: platform.RoomRole.host,
      displayName: name.value,
      controlPort: defaults.controlPort,
      audioPort: defaults.audioPort,
      bitrateBps: defaults.bitrateBps,
      echoMode: echoMode,
      talkMode: _platformTalkMode(talk.mode),
      vadSensitivity: _platformSensitivity(talk.sensitivity),
    ),
    JoinRoomRequest(:final name, :final host) => platform.RoomConfig(
      role: platform.RoomRole.client,
      hostIp: host.value,
      displayName: name.value,
      controlPort: defaults.controlPort,
      audioPort: defaults.audioPort,
      bitrateBps: defaults.bitrateBps,
      talkMode: _platformTalkMode(talk.mode),
      vadSensitivity: _platformSensitivity(talk.sensitivity),
    ),
  };

  static platform.TalkMode _platformTalkMode(TalkMode mode) => switch (mode) {
    TalkMode.voice => platform.TalkMode.voice,
    TalkMode.pushToTalk => platform.TalkMode.pushToTalk,
  };

  static platform.VadSensitivity _platformSensitivity(
    VadSensitivity sensitivity,
  ) => switch (sensitivity) {
    VadSensitivity.low => platform.VadSensitivity.low,
    VadSensitivity.medium => platform.VadSensitivity.medium,
    VadSensitivity.high => platform.VadSensitivity.high,
  };

  static CoreTalkMode _coreTalkMode(TalkMode mode) => switch (mode) {
    TalkMode.voice => CoreTalkMode.voice,
    TalkMode.pushToTalk => CoreTalkMode.pushToTalk,
  };

  static CoreVadSensitivity _coreSensitivity(VadSensitivity sensitivity) =>
      switch (sensitivity) {
        VadSensitivity.low => CoreVadSensitivity.low,
        VadSensitivity.medium => CoreVadSensitivity.medium,
        VadSensitivity.high => CoreVadSensitivity.high,
      };

  static AudioRoute _route(platform.AudioRoute route) => switch (route) {
    platform.AudioRoute.unknown => AudioRoute.unknown,
    platform.AudioRoute.bluetoothHeadset => AudioRoute.intercom,
    platform.AudioRoute.wiredHeadset => AudioRoute.headset,
    platform.AudioRoute.speaker => AudioRoute.speaker,
    platform.AudioRoute.earpiece => AudioRoute.earpiece,
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

  /// One-way delay this phone can measure: the sender's frame, half the
  /// round trip, the jitter buffer and the playout queue.
  static int? _estimatedDelay(CoreStats stats, CoreDefaults defaults) {
    final rtt = stats.rttMs;
    if (rtt == null) {
      return null;
    }
    final frameMs =
        defaults.frameSamples *
        Duration.millisecondsPerSecond ~/
        defaults.sampleRateHz;
    return frameMs +
        (rtt / _halves).round() +
        stats.jitterBufferMs +
        stats.playoutQueueMs;
  }

  static SessionStats _toEntity(CoreStats stats, CoreDefaults defaults) =>
      SessionStats(
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
        captureOverruns: stats.captureOverruns,
        playoutQueueMs: stats.playoutQueueMs,
        estimatedDelayMs: _estimatedDelay(stats, defaults),
      );
}
