import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/voice_platform.dart';

import '../support/mock_host_api.dart';
import '../support/samples.dart';

void main() {
  setUpAll(registerHostApiFallbacks);

  late MockVoicePlatformHostApi hostApi;
  late StreamController<PlatformStateMessage> states;
  late PigeonVoicePlatformGateway gateway;

  setUp(() {
    hostApi = MockVoicePlatformHostApi();
    stubHostApiSuccess(hostApi);
    states = StreamController<PlatformStateMessage>();
    gateway = PigeonVoicePlatformGateway(
      hostApi: hostApi,
      platformStates: () => states.stream,
    );
  });

  // close() never completes for a stream nobody listened to, so do not wait.
  tearDown(() => unawaited(states.close()));

  group('PigeonVoicePlatformGateway forwards', () {
    test('the room configuration as a message', () async {
      await gateway.startRoom(sampleClientConfig);

      verify(() => hostApi.startRoom(sampleClientConfigMessage())).called(1);
    });

    test('the mute flag', () async {
      await gateway.setMute(muted: true);
      await gateway.setMute(muted: false);

      verifyInOrder([
        () => hostApi.setMute(true),
        () => hostApi.setMute(false),
      ]);
    });

    test('the keep screen on flag', () async {
      await gateway.setKeepScreenOn(enabled: true);

      verify(() => hostApi.setKeepScreenOn(true)).called(1);
    });

    test('stop and settings calls without arguments', () async {
      await gateway.stopRoom();
      await gateway.openHotspotSettings();

      verify(hostApi.stopRoom).called(1);
      verify(hostApi.openHotspotSettings).called(1);
    });
  });

  group('PigeonVoicePlatformGateway errors', () {
    test('lets non-platform errors through unchanged', () {
      final error = StateError('unexpected');
      when(hostApi.stopRoom).thenThrow(error);

      expect(gateway.stopRoom(), throwsA(same(error)));
    });

    test('lets non-platform stream errors through unchanged', () async {
      final error = StateError('unexpected');
      final errors = <Object>[];
      final subscription = gateway.watchPlatformState().listen(
        (_) {},
        onError: errors.add,
      );

      states.addError(error);
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, [same(error)]);
    });
  });

  test('can be created with the generated channels', () {
    expect(PigeonVoicePlatformGateway(), isA<VoicePlatformGateway>());
  });
}
