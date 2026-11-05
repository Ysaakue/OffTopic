import 'package:flutter_test/flutter_test.dart';
import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/src/message_mappers.dart';
import 'package:voice_platform/voice_platform.dart';

import '../support/samples.dart';

void main() {
  group('RoomRole', () {
    test('round-trips through every message value', () {
      for (final role in RoomRole.values) {
        expect(role.toMessage().toModel(), role);
      }
    });

    test('maps to the message with the same name', () {
      expect(RoomRole.host.toMessage(), RoomRoleMessage.host);
      expect(RoomRole.client.toMessage(), RoomRoleMessage.client);
    });
  });

  test('AudioRouteMessage maps every value to the same-named route', () {
    for (final message in AudioRouteMessage.values) {
      expect(message.toModel().name, message.name);
    }
  });

  test('WifiStateMessage maps every value to the same-named state', () {
    for (final message in WifiStateMessage.values) {
      expect(message.toModel().name, message.name);
    }
  });

  test('TalkMode round-trips through the same-named message', () {
    for (final mode in TalkMode.values) {
      expect(mode.toMessage().name, mode.name);
      expect(mode.toMessage().toModel(), mode);
    }
  });

  test('VadSensitivity round-trips through the same-named message', () {
    for (final sensitivity in VadSensitivity.values) {
      expect(sensitivity.toMessage().name, sensitivity.name);
      expect(sensitivity.toMessage().toModel(), sensitivity);
    }
  });

  group('RoomConfig', () {
    test('converts to a message field by field', () {
      final message = sampleClientConfig.toMessage();

      expect(message, sampleClientConfigMessage());
    });

    test('round-trips, including a null host IP and echo mode', () {
      for (final config in [
        sampleClientConfig,
        sampleHostConfig,
        sampleEchoHostConfig,
        samplePushToTalkConfig,
      ]) {
        expect(config.toMessage().toModel(), config);
      }
    });
  });

  test('PlatformInfoMessage converts with its capabilities', () {
    expect(samplePlatformInfoMessage().toModel(), samplePlatformInfo);
  });

  test('ActiveRoomMessage converts the config and the mute state', () {
    final message = ActiveRoomMessage(
      config: sampleClientConfigMessage(),
      muted: true,
    );

    expect(
      message.toModel(),
      const ActiveRoom(config: sampleClientConfig, muted: true),
    );
  });

  test('PlatformStateMessage converts every field', () {
    final message = PlatformStateMessage(
      serviceRunning: true,
      audioRoute: AudioRouteMessage.bluetoothHeadset,
      wifiState: WifiStateMessage.connected,
      systemCall: true,
    );

    expect(
      message.toModel(),
      const PlatformState(
        serviceRunning: true,
        audioRoute: AudioRoute.bluetoothHeadset,
        wifiState: WifiState.connected,
        systemCall: true,
      ),
    );
  });
}
