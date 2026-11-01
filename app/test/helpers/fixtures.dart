import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:voice_platform/voice_platform.dart';

const samplePlatformInfo = PlatformInfo(
  osName: 'android',
  osVersion: '17',
  apiLevel: 37,
  manufacturer: 'Xiaomi',
  model: 'Redmi Note 13',
  capabilities: PlatformCapabilities(
    canHostRoom: true,
    supportsGatewayDiscovery: true,
    supportsHotspotSettings: true,
    supportsBatteryExemption: true,
  ),
);

const sampleAppInfo = AppInfo(
  coreVersion: '0.1.0',
  manufacturer: 'Xiaomi',
  model: 'Redmi Note 13',
  osName: 'android',
  osVersion: '17',
);
