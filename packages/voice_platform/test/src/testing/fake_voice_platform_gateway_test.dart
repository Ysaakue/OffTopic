import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../support/samples.dart';

void main() {
  group('FakeVoicePlatformGateway', () {
    late FakeVoicePlatformGateway fake;

    setUp(() => fake = FakeVoicePlatformGateway());
    tearDown(() => fake.dispose());

    test('looks like an Android 17 phone by default', () async {
      final info = await fake.getPlatformInfo();

      expect(info.osName, 'android');
      expect(info.apiLevel, 37);
      expect(info.capabilities.canHostRoom, isTrue);
    });

    test('startRoom makes the room active and unmuted', () async {
      await fake.startRoom(sampleClientConfig);

      expect(
        await fake.getActiveRoom(),
        const ActiveRoom(config: sampleClientConfig, muted: false),
      );
    });

    test('setMute updates the active room', () async {
      await fake.startRoom(sampleHostConfig);

      await fake.setMute(muted: true);

      expect((await fake.getActiveRoom())?.muted, isTrue);
    });

    test('setMute without a room changes nothing', () async {
      await fake.setMute(muted: true);

      expect(await fake.getActiveRoom(), isNull);
    });

    test('stopRoom clears the active room', () async {
      await fake.startRoom(sampleClientConfig);

      await fake.stopRoom();

      expect(await fake.getActiveRoom(), isNull);
    });

    test('records settings, screen and battery calls', () async {
      fake.batteryExempt = true;

      await fake.openHotspotSettings();
      await fake.setKeepScreenOn(enabled: true);
      final exempt = await fake.requestBatteryExemption();

      expect(fake.hotspotSettingsOpened, 1);
      expect(fake.keepScreenOn, isTrue);
      expect(exempt, isTrue);
      expect(fake.calls, [
        PlatformCall.openHotspotSettings,
        PlatformCall.setKeepScreenOn,
        PlatformCall.requestBatteryExemption,
      ]);
    });

    test('fails a call until the failure is cleared', () async {
      const error = VoicePlatformException(code: 'boom');
      fake.failWith(PlatformCall.stopRoom, error);

      await expectLater(fake.stopRoom(), throwsA(same(error)));

      fake.clearFailure(PlatformCall.stopRoom);
      await expectLater(fake.stopRoom(), completes);
    });

    test('holds a call until released, then answers normally', () async {
      final release = Completer<void>();
      fake.holdUntil(PlatformCall.getPlatformInfo, release.future);
      var answered = false;

      final pending = fake.getPlatformInfo().then((_) => answered = true);
      await pumpEventQueue();
      expect(answered, isFalse);

      release.complete();
      await pending;
      expect(answered, isTrue);
    });

    test('a hold applies to the next call only', () async {
      fake.holdUntil(PlatformCall.stopRoom, Future<void>.value());

      await fake.stopRoom();

      await expectLater(fake.stopRoom(), completes);
      expect(fake.calls, [PlatformCall.stopRoom, PlatformCall.stopRoom]);
    });

    test('new state listeners start from the latest state', () async {
      const running = PlatformState(
        serviceRunning: true,
        audioRoute: AudioRoute.speaker,
        wifiState: WifiState.connected,
      );
      fake.emitState(running);

      expect(await fake.watchPlatformState().first, running);
    });
  });
}
