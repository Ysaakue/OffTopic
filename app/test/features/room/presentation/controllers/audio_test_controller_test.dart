import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fake_key_value_store.dart';
import '../../../../helpers/fake_permission_requester.dart';
import '../../../../helpers/room_fixtures.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late FakePermissionRequester permissions;
  late FakeKeyValueStore store;
  late ProviderContainer container;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
    permissions = FakePermissionRequester();
    store = FakeKeyValueStore();
    container = ProviderContainer(
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
        permissionRequesterProvider.overrideWithValue(permissions),
        keyValueStoreProvider.overrideWithValue(store),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(platform.dispose());
  });

  AudioTestState state() => container.read(audioTestControllerProvider);
  Future<void> start() =>
      container.read(audioTestControllerProvider.notifier).start(joinRequest);
  Future<void> stop() =>
      container.read(audioTestControllerProvider.notifier).stop();

  test('starts idle', () {
    expect(state(), const AudioTestIdle());
  });

  test('the phone ending the call ends the room', () async {
    await start();
    expect(state(), AudioTestActive(joinRequest));

    core.emitEvent(const CoreStateChanged(CoreState.stopped));
    await pumpEventQueue();

    expect(
      state(),
      const AudioTestFailed(
        RoomFailure(
          RoomFailureReason.endedBySystem,
          'The phone ended the call.',
        ),
      ),
    );
  });

  test(
    'a stop asked from here is not reported as the phone ending it',
    () async {
      await start();

      await stop();
      core.emitEvent(const CoreStateChanged(CoreState.stopped));
      await pumpEventQueue();

      expect(state(), const AudioTestIdle());
    },
  );

  test('push to talk reaches the core only while a room runs', () async {
    final controller = container.read(audioTestControllerProvider.notifier)
      ..setPushToTalk(pressed: true);
    expect(core.pushToTalk, isEmpty);

    await start();
    controller
      ..setPushToTalk(pressed: true)
      ..setPushToTalk(pressed: false);

    expect(core.pushToTalk, [true, false]);
  });

  test('goes from starting to active', () async {
    final hold = Completer<void>();
    platform.holdUntil(PlatformCall.startRoom, hold.future);

    final starting = start();
    await pumpEventQueue();
    expect(state(), const AudioTestStarting());

    hold.complete();
    await starting;
    expect(state(), AudioTestActive(joinRequest));
    expect(platform.activeRoom, isNotNull);
  });

  test('ignores a second start while busy', () async {
    await start();
    await start();

    expect(
      platform.calls.where((call) => call == PlatformCall.startRoom),
      hasLength(1),
    );
  });

  test('stops through stopping back to idle', () async {
    await start();
    final hold = Completer<void>();
    platform.holdUntil(PlatformCall.stopRoom, hold.future);

    final stopping = stop();
    await pumpEventQueue();
    expect(state(), const AudioTestStopping());

    hold.complete();
    await stopping;
    expect(state(), const AudioTestIdle());
  });

  test('stop does nothing without a running room', () async {
    await stop();

    expect(platform.calls, isNot(contains(PlatformCall.stopRoom)));
  });

  test('reports a refused permission', () async {
    permissions.statuses[AppPermission.microphone] =
        AppPermissionStatus.permanentlyDenied;

    await start();

    expect(state(), const AudioTestPermissionDenied(permanently: true));
    expect(platform.calls, isNot(contains(PlatformCall.startRoom)));
  });

  test('reports a failed start and returns to the form', () async {
    platform.failWith(
      PlatformCall.startRoom,
      const VoicePlatformException(code: 'audio_device_error', message: 'mic'),
    );

    await start();
    expect(
      state(),
      const AudioTestFailed(RoomFailure(RoomFailureReason.audioDevice, 'mic')),
    );

    container.read(audioTestControllerProvider.notifier).dismiss();
    expect(state(), const AudioTestIdle());
  });

  test('can start again after a failure or a refused permission', () async {
    permissions.statuses[AppPermission.microphone] = AppPermissionStatus.denied;
    await start();
    expect(state(), const AudioTestPermissionDenied(permanently: false));

    permissions.statuses[AppPermission.microphone] =
        AppPermissionStatus.granted;
    platform.failWith(
      PlatformCall.startRoom,
      const VoicePlatformException(code: 'network_error'),
    );
    await start();
    expect(state(), isA<AudioTestFailed>());

    platform.clearFailure(PlatformCall.startRoom);
    await start();
    expect(state(), AudioTestActive(joinRequest));
  });

  test('reports a failed stop', () async {
    await start();
    platform.failWith(
      PlatformCall.stopRoom,
      const VoicePlatformException(code: 'core_error', message: 'x'),
    );

    await stop();

    expect(state(), isA<AudioTestFailed>());
  });

  test('dismiss leaves other states alone', () async {
    await start();

    container.read(audioTestControllerProvider.notifier).dismiss();

    expect(state(), AudioTestActive(joinRequest));
  });

  test('opens the app settings', () async {
    await container.read(audioTestControllerProvider.notifier).openSettings();

    expect(permissions.settingsOpened, 1);
  });

  test('ignores a result that arrives after disposal', () async {
    final hold = Completer<void>();
    platform.holdUntil(PlatformCall.startRoom, hold.future);
    final starting = start();
    await pumpEventQueue();

    container.dispose();
    hold.complete();
    await starting; // must not throw on the disposed notifier
  });

  test('ignores a stop result that arrives after disposal', () async {
    await start();
    final hold = Completer<void>();
    platform.holdUntil(PlatformCall.stopRoom, hold.future);
    final stopping = stop();
    await pumpEventQueue();

    container.dispose();
    hold.complete();
    await stopping;
  });

  group('session statistics', () {
    test('are not read without an active room', () {
      fakeAsync((async) {
        final subscription = container.listen(sessionStatsProvider, (_, _) {});
        async.elapse(const Duration(seconds: 1));

        expect(core.statsReads, 0);
        subscription.close();
      });
    });

    test('are read at 4 Hz while the room is active', () {
      fakeAsync((async) {
        core.stats = sampleCoreStats;
        unawaited(start());
        async.flushMicrotasks();
        final subscription = container.listen(sessionStatsProvider, (_, _) {});

        async.elapse(const Duration(seconds: 1));

        expect(core.statsReads, 4);
        expect(container.read(sessionStatsProvider).value, sampleSessionStats);
        subscription.close();
      });
    });
  });

  test('state values compare by value', () {
    expect(
      const AudioTestPermissionDenied(permanently: false),
      isNot(const AudioTestPermissionDenied(permanently: true)),
    );
    expect(const AudioTestIdle().props, isEmpty);
  });
}
