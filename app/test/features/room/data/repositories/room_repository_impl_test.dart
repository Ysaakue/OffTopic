import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/data/repositories/room_repository_impl.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart'
    as domain;
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart'
    as domain;
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late RoomRepositoryImpl repository;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
    repository = RoomRepositoryImpl(
      rooms: platform,
      platformState: platform,
      core: core,
    );
  });

  tearDown(() {
    unawaited(platform.dispose());
    core.dispose();
  });

  group('start', () {
    test('joins with the host address and the core defaults', () async {
      expect(
        await repository.start(joinRequest, talk: defaultTalk),
        const Success<void>(null),
      );

      expect(
        platform.activeRoom?.config,
        const RoomConfig(
          role: RoomRole.client,
          hostIp: '192.168.43.1',
          displayName: 'Rider',
          controlPort: 47800,
          audioPort: 47801,
          bitrateBps: 24000,
        ),
      );
    });

    test('hosts with echo mode and no host address', () async {
      await repository.start(echoRequest, talk: defaultTalk);

      expect(
        platform.activeRoom?.config,
        const RoomConfig(
          role: RoomRole.host,
          displayName: 'Rider',
          controlPort: 47800,
          audioPort: 47801,
          bitrateBps: 24000,
          echoMode: true,
        ),
      );
    });

    test('maps every platform error to a room failure reason', () async {
      for (final (code, reason) in [
        (
          VoicePlatformErrorCode.roomAlreadyActive,
          RoomFailureReason.alreadyActive,
        ),
        (VoicePlatformErrorCode.invalidConfig, RoomFailureReason.invalidConfig),
        (
          VoicePlatformErrorCode.audioDeviceError,
          RoomFailureReason.audioDevice,
        ),
        (VoicePlatformErrorCode.networkError, RoomFailureReason.network),
        (VoicePlatformErrorCode.coreError, RoomFailureReason.unavailable),
        (VoicePlatformErrorCode.channelError, RoomFailureReason.unavailable),
      ]) {
        platform.failWith(
          PlatformCall.startRoom,
          VoicePlatformException(code: code, message: 'detail'),
        );

        expect(
          await repository.start(joinRequest, talk: defaultTalk),
          Failure<void>(RoomFailure(reason, 'detail')),
          reason: code,
        );
      }
    });

    test('uses the code when the platform gives no message', () async {
      platform.failWith(
        PlatformCall.startRoom,
        const VoicePlatformException(code: 'network_error'),
      );

      expect(
        await repository.start(joinRequest, talk: defaultTalk),
        const Failure<void>(
          RoomFailure(RoomFailureReason.network, 'network_error'),
        ),
      );
    });

    test('reports an unavailable core', () async {
      final brokenCore = _BrokenDefaultsCore();
      final result = await RoomRepositoryImpl(
        rooms: platform,
        platformState: platform,
        core: brokenCore,
      ).start(joinRequest, talk: defaultTalk);

      expect(result, const Failure<void>(CoreFailure('no defaults')));
      expect(platform.calls, isNot(contains(PlatformCall.startRoom)));
    });
  });

  group('stop', () {
    test('stops the room', () async {
      await repository.start(joinRequest, talk: defaultTalk);

      expect(await repository.stop(), const Success<void>(null));
      expect(platform.activeRoom, isNull);
    });

    test('maps a platform failure', () async {
      platform.failWith(
        PlatformCall.stopRoom,
        const VoicePlatformException(code: 'core_error', message: 'x'),
      );

      expect(
        await repository.stop(),
        const Failure<void>(RoomFailure(RoomFailureReason.unavailable, 'x')),
      );
    });
  });

  group('readStats', () {
    test('is empty while no session runs', () {
      expect(repository.readStats(), const Success<SessionStats?>(null));
    });

    test('maps the core statistics', () {
      core.stats = sampleCoreStats;

      expect(
        repository.readStats(),
        const Success<SessionStats?>(sampleSessionStats),
      );
    });

    test('has no delay estimate before the round trip is known', () {
      core.stats = const CoreStats(
        participants: 1,
        lossPct: 0,
        jitterMs: 0,
        jitterBufferMs: 40,
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
        playoutQueueMs: 30,
      );

      final stats = (repository.readStats() as Success<SessionStats?>).value;

      expect(stats?.estimatedDelayMs, isNull);
      expect(stats?.playoutQueueMs, 30);
    });

    test('maps a core failure', () {
      core.statsError = const VoiceCoreException('gone');

      expect(
        repository.readStats(),
        const Failure<SessionStats?>(CoreFailure('gone')),
      );
    });
  });

  group('watchLink', () {
    test('forwards link changes and skips the rest', () async {
      final links = <RoomLink>[];
      final subscription = repository.watchLink().listen(links.add);

      core
        ..emitEvent(const CoreStateChanged(CoreState.running))
        ..emitInvalidEvent()
        ..emitEvent(const CoreLinkChanged(up: true, peer: '10.0.0.2:5000'))
        ..emitEvent(const CoreLinkChanged(up: false, peer: '10.0.0.2:5000'));
      await pumpEventQueue();

      expect(links, const [
        RoomLink(up: true, peer: '10.0.0.2:5000'),
        RoomLink(up: false, peer: '10.0.0.2:5000'),
      ]);
      await subscription.cancel();
    });
  });

  group('talk settings', () {
    test('start sends the talk mode and sensitivity to the platform', () async {
      await repository.start(joinRequest, talk: pushToTalkSettings);

      expect(platform.activeRoom?.config.talkMode, TalkMode.pushToTalk);
      expect(platform.activeRoom?.config.vadSensitivity, VadSensitivity.high);
    });

    test('start maps every sensitivity', () async {
      for (final (sensitivity, expected) in [
        (domain.VadSensitivity.low, VadSensitivity.low),
        (domain.VadSensitivity.medium, VadSensitivity.medium),
        (domain.VadSensitivity.high, VadSensitivity.high),
      ]) {
        await repository.start(
          hostRequest,
          talk: domain.TalkSettings(sensitivity: sensitivity),
        );
        expect(platform.activeRoom?.config.vadSensitivity, expected);
        await repository.stop();
      }
    });

    test('applies the settings to the running core', () {
      expect(
        repository.applyTalkSettings(pushToTalkSettings),
        const Success<void>(null),
      );
      expect(
        repository.applyTalkSettings(
          const domain.TalkSettings(sensitivity: domain.VadSensitivity.low),
        ),
        const Success<void>(null),
      );
      repository.applyTalkSettings(defaultTalk);

      expect(core.talkModes, [
        CoreTalkMode.pushToTalk,
        CoreTalkMode.voice,
        CoreTalkMode.voice,
      ]);
      expect(core.vadSensitivities, [
        CoreVadSensitivity.high,
        CoreVadSensitivity.low,
        CoreVadSensitivity.medium,
      ]);
    });

    test('maps a refused setting to a core failure', () {
      final refusing = RoomRepositoryImpl(
        rooms: platform,
        platformState: platform,
        core: _BrokenDefaultsCore(),
      );

      expect(
        refusing.applyTalkSettings(defaultTalk),
        const Failure<void>(CoreFailure('refused')),
      );
    });

    test('forwards the push-to-talk button', () {
      repository
        ..setPushToTalk(pressed: true)
        ..setPushToTalk(pressed: false);

      expect(core.pushToTalk, [true, false]);
    });
  });

  group('watchTalking', () {
    test('forwards talking changes and skips the rest', () async {
      final talking = <bool>[];
      final subscription = repository.watchTalking().listen(talking.add);

      core
        ..emitEvent(const CoreStateChanged(CoreState.running))
        ..emitInvalidEvent()
        ..emitEvent(const CoreLinkChanged(up: true, peer: '10.0.0.2:5000'))
        ..emitEvent(const CoreTalkingChanged(talking: true))
        ..emitEvent(const CoreTalkingChanged(talking: false));
      await pumpEventQueue();

      expect(talking, [true, false]);
      await subscription.cancel();
    });
  });

  group('watchAudio', () {
    test(
      'maps every route and the call mode, skipping repeats and errors',
      () async {
        final audio = <RoomAudio>[];
        final subscription = repository.watchAudio().listen(audio.add);
        await pumpEventQueue();

        for (final route in [
          AudioRoute.bluetoothHeadset,
          AudioRoute.bluetoothHeadset,
          AudioRoute.wiredHeadset,
          AudioRoute.speaker,
          AudioRoute.earpiece,
        ]) {
          platform.emitState(_state(route, systemCall: true));
        }
        platform
          ..emitState(_state(AudioRoute.earpiece))
          ..emitStateError(const VoicePlatformException(code: 'gone'));
        await pumpEventQueue();

        expect(audio, const [
          RoomAudio(),
          RoomAudio(route: domain.AudioRoute.intercom, systemCall: true),
          RoomAudio(route: domain.AudioRoute.headset, systemCall: true),
          RoomAudio(route: domain.AudioRoute.speaker, systemCall: true),
          RoomAudio(route: domain.AudioRoute.earpiece, systemCall: true),
          RoomAudio(route: domain.AudioRoute.earpiece),
        ]);
        await subscription.cancel();
      },
    );
  });

  group('watchSessionStopped', () {
    test('reports each stop of the native session', () async {
      var stops = 0;
      final subscription = repository.watchSessionStopped().listen(
        (_) => stops++,
      );

      core
        ..emitEvent(const CoreStateChanged(CoreState.running))
        ..emitEvent(const CoreStateChanged(CoreState.failed, errorCode: -3))
        ..emitEvent(const CoreTalkingChanged(talking: true))
        ..emitEvent(const CoreStateChanged(CoreState.stopped));
      await pumpEventQueue();

      expect(stops, 1);
      await subscription.cancel();
    });
  });
}

final class _BrokenDefaultsCore implements VoiceCoreClient {
  final _fake = FakeVoiceCoreClient();

  @override
  CoreDefaults get defaults => throw const VoiceCoreException('no defaults');

  @override
  String get version => _fake.version;

  @override
  CoreStats? readStats() => _fake.readStats();

  @override
  Stream<CoreEvent> get events => _fake.events;

  @override
  void setOutputGain(double gain) => _fake.setOutputGain(gain);

  @override
  void setTalkMode(CoreTalkMode mode) =>
      throw const VoiceCoreException('refused');

  @override
  void setPushToTalk({required bool pressed}) =>
      _fake.setPushToTalk(pressed: pressed);

  @override
  void setVadSensitivity(CoreVadSensitivity sensitivity) =>
      _fake.setVadSensitivity(sensitivity);

  @override
  void dispose() => _fake.dispose();
}

PlatformState _state(AudioRoute route, {bool systemCall = false}) =>
    PlatformState(
      serviceRunning: false,
      audioRoute: route,
      wifiState: WifiState.unknown,
      systemCall: systemCall,
    );
