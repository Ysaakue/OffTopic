import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/voice_platform.dart';

const sampleCapabilities = PlatformCapabilities(
  canHostRoom: true,
  supportsGatewayDiscovery: true,
  supportsHotspotSettings: false,
  supportsBatteryExemption: true,
);

const samplePlatformInfo = PlatformInfo(
  osName: 'android',
  osVersion: '14',
  apiLevel: 34,
  manufacturer: 'samsung',
  model: 'SM-S921B',
  capabilities: sampleCapabilities,
);

const sampleClientConfig = RoomConfig(
  role: RoomRole.client,
  hostIp: '192.168.43.1',
  displayName: 'Ana',
  controlPort: 47800,
  audioPort: 47801,
  bitrateBps: 24000,
);

const sampleHostConfig = RoomConfig(
  role: RoomRole.host,
  displayName: 'Bia',
  controlPort: 47800,
  audioPort: 47801,
  bitrateBps: 24000,
);

PlatformInfoMessage samplePlatformInfoMessage() => PlatformInfoMessage(
  osName: 'android',
  osVersion: '14',
  apiLevel: 34,
  manufacturer: 'samsung',
  model: 'SM-S921B',
  capabilities: PlatformCapabilitiesMessage(
    canHostRoom: true,
    supportsGatewayDiscovery: true,
    supportsHotspotSettings: false,
    supportsBatteryExemption: true,
  ),
);

RoomConfigMessage sampleClientConfigMessage() => RoomConfigMessage(
  role: RoomRoleMessage.client,
  hostIp: '192.168.43.1',
  displayName: 'Ana',
  controlPort: 47800,
  audioPort: 47801,
  bitrateBps: 24000,
);
