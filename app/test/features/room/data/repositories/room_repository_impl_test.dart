import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/data/repositories/room_repository_impl.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
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
    repository = RoomRepositoryImpl(rooms: platform, core: core);
  });

  tearDown(() {
    unawaited(platform.dispose());
    core.dispose();
  });

  group('start', () {
    test('joins with the host address and the core defaults', () async {
      expect(await repository.start(joinRequest), const Success<void>(null));

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
      await repository.start(echoRequest);

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
          await repository.start(joinRequest),
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
        await repository.start(joinRequest),
        const Failure<void>(
          RoomFailure(RoomFailureReason.network, 'network_error'),
        ),
      );
    });

    test('reports an unavailable core', () async {
      final brokenCore = _BrokenDefaultsCore();
      final result = await RoomRepositoryImpl(
        rooms: platform,
        core: brokenCore,
      ).start(joinRequest);

      expect(result, const Failure<void>(CoreFailure('no defaults')));
      expect(platform.calls, isNot(contains(PlatformCall.startRoom)));
    });
  });

  group('stop', () {
    test('stops the room', () async {
      await repository.start(joinRequest);

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
  void dispose() => _fake.dispose();
}
