import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart'
    as domain;
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart'
    as domain;
import 'package:offtopic/features/settings/settings_providers.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fake_key_value_store.dart';
import '../../../../helpers/fake_permission_requester.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/room_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 4, 20);

  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late ProviderContainer container;
  late DateTime clock;

  setUp(() {
    clock = now;
    platform = FakeVoicePlatformGateway(platformInfo: samplePlatformInfo);
    core = FakeVoiceCoreClient(version: '0.1.0')..stats = sampleCoreStats;
    container = ProviderContainer(
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
        permissionRequesterProvider.overrideWithValue(
          FakePermissionRequester(),
        ),
        keyValueStoreProvider.overrideWithValue(FakeKeyValueStore()),
        clockProvider.overrideWithValue(() => clock),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(platform.dispose());
  });

  SessionReport? report() => container.read(sessionReportControllerProvider);

  test('has no report before the first room', () {
    expect(report(), isNull);
  });

  test('records a room from start to end', () {
    fakeAsync((async) {
      container.listen(sessionReportControllerProvider, (_, _) {});
      final controller = container.read(audioTestControllerProvider.notifier);
      container.read(talkSettingsControllerProvider);
      async.flushMicrotasks();

      unawaited(controller.start(joinRequest));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));
      platform.emitState(
        const PlatformState(
          serviceRunning: false,
          audioRoute: AudioRoute.bluetoothHeadset,
          wifiState: WifiState.unknown,
          systemCall: true,
        ),
      );
      core
        ..emitEvent(const CoreLinkChanged(up: false, peer: '10.0.0.2:47801'))
        ..emitEvent(const CoreLinkChanged(up: true, peer: '10.0.0.2:47801'));
      async.flushMicrotasks();
      unawaited(
        container
            .read(talkSettingsControllerProvider.notifier)
            .setMode(domain.TalkMode.pushToTalk),
      );
      async.flushMicrotasks();

      final running = report()!;
      expect(running.request, joinRequest);
      expect(running.startedAt, now);
      expect(running.endedAt, isNull);
      expect(running.appInfo?.coreVersion, '0.1.0');
      expect(running.audio.systemCall, isTrue);
      expect(running.routes, contains(domain.AudioRoute.intercom));
      expect(running.linkDrops, 1);
      expect(running.talk.mode, domain.TalkMode.pushToTalk);
      expect(running.delay.count, greaterThan(0));

      clock = now.add(const Duration(minutes: 3));
      unawaited(controller.stop());
      async.flushMicrotasks();

      expect(report()?.endedAt, clock);
      final samples = report()!.delay.count;
      async.elapse(const Duration(seconds: 1));
      expect(report()!.delay.count, samples); // nothing more after the end
    });
  });

  test('keeps nothing from events outside a room', () {
    fakeAsync((async) {
      container.listen(sessionReportControllerProvider, (_, _) {});
      core.emitEvent(const CoreLinkChanged(up: false, peer: 'a'));
      platform.emitState(PlatformState.idle);
      async.flushMicrotasks();

      expect(report(), isNull);
    });
  });

  test('reports without the device when the platform cannot say', () {
    fakeAsync((async) {
      platform.failWith(
        PlatformCall.getPlatformInfo,
        const VoicePlatformException(code: 'channel-error'),
      );
      container.listen(sessionReportControllerProvider, (_, _) {});

      unawaited(
        container.read(audioTestControllerProvider.notifier).start(hostRequest),
      );
      async.flushMicrotasks();

      expect(report()?.appInfo, isNull);
      expect(report()?.talk, const domain.TalkSettings());
    });
  });
}
