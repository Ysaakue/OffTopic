import 'package:voice_platform/src/generated/voice_platform_api.g.dart';
import 'package:voice_platform/src/models/active_room.dart';
import 'package:voice_platform/src/models/audio_route.dart';
import 'package:voice_platform/src/models/platform_capabilities.dart';
import 'package:voice_platform/src/models/platform_info.dart';
import 'package:voice_platform/src/models/platform_state.dart';
import 'package:voice_platform/src/models/room_config.dart';
import 'package:voice_platform/src/models/room_role.dart';
import 'package:voice_platform/src/models/talk_mode.dart';
import 'package:voice_platform/src/models/vad_sensitivity.dart';
import 'package:voice_platform/src/models/wifi_state.dart';

// Conversions between the Pigeon messages and the public models. The public
// API never exposes a generated type.

/// Converts [RoomRole] to its message.
extension RoomRoleToMessage on RoomRole {
  /// The Pigeon message for this role.
  RoomRoleMessage toMessage() => switch (this) {
    RoomRole.host => RoomRoleMessage.host,
    RoomRole.client => RoomRoleMessage.client,
  };
}

/// Converts [RoomRoleMessage] to the model.
extension RoomRoleMessageToModel on RoomRoleMessage {
  /// The public model for this message.
  RoomRole toModel() => switch (this) {
    RoomRoleMessage.host => RoomRole.host,
    RoomRoleMessage.client => RoomRole.client,
  };
}

/// Converts [AudioRouteMessage] to the model.
extension AudioRouteMessageToModel on AudioRouteMessage {
  /// The public model for this message.
  AudioRoute toModel() => switch (this) {
    AudioRouteMessage.unknown => AudioRoute.unknown,
    AudioRouteMessage.bluetoothHeadset => AudioRoute.bluetoothHeadset,
    AudioRouteMessage.wiredHeadset => AudioRoute.wiredHeadset,
    AudioRouteMessage.speaker => AudioRoute.speaker,
    AudioRouteMessage.earpiece => AudioRoute.earpiece,
  };
}

/// Converts [WifiStateMessage] to the model.
extension WifiStateMessageToModel on WifiStateMessage {
  /// The public model for this message.
  WifiState toModel() => switch (this) {
    WifiStateMessage.unknown => WifiState.unknown,
    WifiStateMessage.disconnected => WifiState.disconnected,
    WifiStateMessage.connected => WifiState.connected,
  };
}

/// Converts [TalkMode] to its message.
extension TalkModeToMessage on TalkMode {
  /// The Pigeon message for this mode.
  TalkModeMessage toMessage() => switch (this) {
    TalkMode.voice => TalkModeMessage.voice,
    TalkMode.pushToTalk => TalkModeMessage.pushToTalk,
  };
}

/// Converts [TalkModeMessage] to the model.
extension TalkModeMessageToModel on TalkModeMessage {
  /// The public model for this message.
  TalkMode toModel() => switch (this) {
    TalkModeMessage.voice => TalkMode.voice,
    TalkModeMessage.pushToTalk => TalkMode.pushToTalk,
  };
}

/// Converts [VadSensitivity] to its message.
extension VadSensitivityToMessage on VadSensitivity {
  /// The Pigeon message for this sensitivity.
  VadSensitivityMessage toMessage() => switch (this) {
    VadSensitivity.low => VadSensitivityMessage.low,
    VadSensitivity.medium => VadSensitivityMessage.medium,
    VadSensitivity.high => VadSensitivityMessage.high,
  };
}

/// Converts [VadSensitivityMessage] to the model.
extension VadSensitivityMessageToModel on VadSensitivityMessage {
  /// The public model for this message.
  VadSensitivity toModel() => switch (this) {
    VadSensitivityMessage.low => VadSensitivity.low,
    VadSensitivityMessage.medium => VadSensitivity.medium,
    VadSensitivityMessage.high => VadSensitivity.high,
  };
}

/// Converts [RoomConfig] to its message.
extension RoomConfigToMessage on RoomConfig {
  /// The Pigeon message for this configuration.
  RoomConfigMessage toMessage() => RoomConfigMessage(
    role: role.toMessage(),
    hostIp: hostIp,
    displayName: displayName,
    controlPort: controlPort,
    audioPort: audioPort,
    bitrateBps: bitrateBps,
    echoMode: echoMode,
    talkMode: talkMode.toMessage(),
    vadSensitivity: vadSensitivity.toMessage(),
  );
}

/// Converts [RoomConfigMessage] to the model.
extension RoomConfigMessageToModel on RoomConfigMessage {
  /// The public model for this message.
  RoomConfig toModel() => RoomConfig(
    role: role.toModel(),
    hostIp: hostIp,
    displayName: displayName,
    controlPort: controlPort,
    audioPort: audioPort,
    bitrateBps: bitrateBps,
    echoMode: echoMode,
    talkMode: talkMode.toModel(),
    vadSensitivity: vadSensitivity.toModel(),
  );
}

/// Converts [PlatformCapabilitiesMessage] to the model.
extension PlatformCapabilitiesMessageToModel on PlatformCapabilitiesMessage {
  /// The public model for this message.
  PlatformCapabilities toModel() => PlatformCapabilities(
    canHostRoom: canHostRoom,
    supportsGatewayDiscovery: supportsGatewayDiscovery,
    supportsHotspotSettings: supportsHotspotSettings,
    supportsBatteryExemption: supportsBatteryExemption,
  );
}

/// Converts [PlatformInfoMessage] to the model.
extension PlatformInfoMessageToModel on PlatformInfoMessage {
  /// The public model for this message.
  PlatformInfo toModel() => PlatformInfo(
    osName: osName,
    osVersion: osVersion,
    apiLevel: apiLevel,
    manufacturer: manufacturer,
    model: model,
    capabilities: capabilities.toModel(),
  );
}

/// Converts [ActiveRoomMessage] to the model.
extension ActiveRoomMessageToModel on ActiveRoomMessage {
  /// The public model for this message.
  ActiveRoom toModel() => ActiveRoom(config: config.toModel(), muted: muted);
}

/// Converts [PlatformStateMessage] to the model.
extension PlatformStateMessageToModel on PlatformStateMessage {
  /// The public model for this message.
  PlatformState toModel() => PlatformState(
    serviceRunning: serviceRunning,
    audioRoute: audioRoute.toModel(),
    wifiState: wifiState.toModel(),
    systemCall: systemCall,
  );
}
