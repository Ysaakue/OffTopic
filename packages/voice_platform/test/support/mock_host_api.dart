import 'package:mocktail/mocktail.dart';
import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/src/message_mappers.dart';
import 'package:voice_platform/voice_platform.dart';

class MockVoicePlatformHostApi extends Mock implements VoicePlatformHostApi;

/// Registers the fallback values mocktail needs for `any()` matchers.
void registerHostApiFallbacks() {
  registerFallbackValue(
    RoomConfigMessage(
      role: RoomRoleMessage.client,
      displayName: 'fallback',
      controlPort: 1,
      audioPort: 1,
      bitrateBps: 1,
      echoMode: false,
      talkMode: TalkModeMessage.voice,
      vadSensitivity: VadSensitivityMessage.medium,
    ),
  );
}

/// Stubs every host method with a successful, neutral answer.
void stubHostApiSuccess(MockVoicePlatformHostApi hostApi) {
  when(() => hostApi.startRoom(any())).thenAnswer((_) async {});
  when(hostApi.stopRoom).thenAnswer((_) async {});
  when(() => hostApi.setMute(any())).thenAnswer((_) async {});
  when(hostApi.openHotspotSettings).thenAnswer((_) async {});
  when(() => hostApi.setKeepScreenOn(any())).thenAnswer((_) async {});
  when(hostApi.getActiveRoom).thenAnswer((_) async => null);
  when(hostApi.requestBatteryExemption).thenAnswer((_) async => false);
}

/// Builds the message the host would send for [info].
PlatformInfoMessage platformInfoMessageFor(PlatformInfo info) =>
    PlatformInfoMessage(
      osName: info.osName,
      osVersion: info.osVersion,
      apiLevel: info.apiLevel,
      manufacturer: info.manufacturer,
      model: info.model,
      capabilities: PlatformCapabilitiesMessage(
        canHostRoom: info.capabilities.canHostRoom,
        supportsGatewayDiscovery: info.capabilities.supportsGatewayDiscovery,
        supportsHotspotSettings: info.capabilities.supportsHotspotSettings,
        supportsBatteryExemption: info.capabilities.supportsBatteryExemption,
      ),
    );

/// Builds the message the host would send for [room].
ActiveRoomMessage activeRoomMessageFor(ActiveRoom room) =>
    ActiveRoomMessage(config: room.config.toMessage(), muted: room.muted);

/// Builds the message the host would send for [state].
PlatformStateMessage platformStateMessageFor(PlatformState state) =>
    PlatformStateMessage(
      serviceRunning: state.serviceRunning,
      audioRoute: AudioRouteMessage.values.byName(state.audioRoute.name),
      wifiState: WifiStateMessage.values.byName(state.wifiState.name),
      systemCall: state.systemCall,
    );
