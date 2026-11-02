import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/features/room/data/services/permission_service_impl.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:voice_platform/testing.dart';
import 'package:voice_platform/voice_platform.dart';

import '../../../../helpers/fake_permission_requester.dart';

PlatformInfo _phone({required int apiLevel, String osName = 'android'}) =>
    PlatformInfo(
      osName: osName,
      osVersion: '$apiLevel',
      apiLevel: apiLevel,
      manufacturer: 'Google',
      model: 'Pixel',
      capabilities: FakeVoicePlatformGateway.defaultPlatformInfo.capabilities,
    );

void main() {
  late FakePermissionRequester requester;
  late FakeVoicePlatformGateway platform;
  late PermissionServiceImpl service;

  setUp(() {
    requester = FakePermissionRequester();
    platform = FakeVoicePlatformGateway();
    service = PermissionServiceImpl(
      requester: requester,
      platformInfo: platform,
    );
  });

  tearDown(() => unawaited(platform.dispose()));

  group('the permissions asked depend on the Android version', () {
    for (final apiLevel in [29, 30, 31, 33, 34]) {
      test('API $apiLevel: the microphone only', () async {
        platform.platformInfo = _phone(apiLevel: apiLevel);

        await service.requestRoomPermissions();

        expect(requester.requests.single, [AppPermission.microphone]);
      });
    }

    test('API 37: the microphone and the local network', () async {
      platform.platformInfo = _phone(apiLevel: 37);

      await service.requestRoomPermissions();

      expect(requester.requests.single, [
        AppPermission.microphone,
        AppPermission.localNetwork,
      ]);
    });

    test('iOS: the microphone only', () async {
      platform.platformInfo = _phone(apiLevel: 37, osName: 'ios');

      await service.requestRoomPermissions();

      expect(requester.requests.single, [AppPermission.microphone]);
    });

    test('unknown platform: the microphone only', () async {
      platform.failWith(
        PlatformCall.getPlatformInfo,
        const VoicePlatformException(code: 'channel-error'),
      );

      await service.requestRoomPermissions();

      expect(requester.requests.single, [AppPermission.microphone]);
    });
  });

  group('the outcome', () {
    test('is granted when everything is granted', () async {
      expect(await service.requestRoomPermissions(), PermissionOutcome.granted);
    });

    test('is denied when one permission is refused', () async {
      requester.statuses[AppPermission.localNetwork] =
          AppPermissionStatus.denied;

      expect(await service.requestRoomPermissions(), PermissionOutcome.denied);
    });

    test('is permanently denied when one cannot be asked again', () async {
      requester.statuses
        ..[AppPermission.microphone] = AppPermissionStatus.denied
        ..[AppPermission.localNetwork] = AppPermissionStatus.permanentlyDenied;

      expect(
        await service.requestRoomPermissions(),
        PermissionOutcome.permanentlyDenied,
      );
    });

    test('is denied when the system gives no answer', () async {
      requester.statuses = {};

      expect(await service.requestRoomPermissions(), PermissionOutcome.denied);
    });
  });

  test('opens the app settings', () async {
    await service.openAppSettings();

    expect(requester.settingsOpened, 1);
  });
}
