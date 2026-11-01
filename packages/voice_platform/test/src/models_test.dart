import 'package:flutter_test/flutter_test.dart';
import 'package:voice_platform/voice_platform.dart';

import '../support/samples.dart';

void main() {
  group('value equality', () {
    test('RoomConfig compares every field', () {
      const same = RoomConfig(
        role: RoomRole.client,
        hostIp: '192.168.43.1',
        displayName: 'Ana',
        controlPort: 47800,
        audioPort: 47801,
        bitrateBps: 24000,
      );
      const otherPort = RoomConfig(
        role: RoomRole.client,
        hostIp: '192.168.43.1',
        displayName: 'Ana',
        controlPort: 47900,
        audioPort: 47801,
        bitrateBps: 24000,
      );

      expect(sampleClientConfig, same);
      expect(sampleClientConfig.hashCode, same.hashCode);
      expect(sampleClientConfig, isNot(otherPort));
    });

    test('PlatformInfo compares nested capabilities', () {
      const differentCapabilities = PlatformInfo(
        osName: 'android',
        osVersion: '14',
        apiLevel: 34,
        manufacturer: 'samsung',
        model: 'SM-S921B',
        capabilities: PlatformCapabilities(
          canHostRoom: false,
          supportsGatewayDiscovery: true,
          supportsHotspotSettings: false,
          supportsBatteryExemption: true,
        ),
      );

      expect(samplePlatformInfo, isNot(differentCapabilities));
    });

    test('ActiveRoom compares the mute state', () {
      const muted = ActiveRoom(config: sampleClientConfig, muted: true);
      const unmuted = ActiveRoom(config: sampleClientConfig, muted: false);

      expect(muted, isNot(unmuted));
      expect(muted, const ActiveRoom(config: sampleClientConfig, muted: true));
    });
  });

  test('PlatformState.idle has no service, no route and unknown Wi-Fi', () {
    expect(PlatformState.idle.serviceRunning, isFalse);
    expect(PlatformState.idle.audioRoute, AudioRoute.unknown);
    expect(PlatformState.idle.wifiState, WifiState.unknown);
  });
}
