// Pigeon definition of the Dart <-> host (Kotlin / Swift) contract.
//
// Regenerate with:
//   fvm dart run pigeon --input pigeons/voice_platform_api.dart
// (from packages/voice_platform). Never edit the generated files by hand.
//
// No audio samples ever cross this channel: it carries commands and state only.
//
// This file is input for the Pigeon parser, not app code: keep classic
// constructors (Pigeon reads them) and positional host parameters (they define
// the generated Kotlin/Swift signatures).
// ignore_for_file: unnecessary_type_name_in_constructor
// ignore_for_file: avoid_positional_boolean_parameters
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/voice_platform_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/isaacgeraldo/offtopic/voiceplatform/generated/VoicePlatformApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.isaacgeraldo.offtopic.voiceplatform.generated',
    ),
    swiftOut:
        'ios/voice_platform/Sources/voice_platform/VoicePlatformApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'voice_platform',
  ),
)
/// Role of this phone in the room.
enum RoomRoleMessage { host, client }

/// Where the room audio is currently routed.
enum AudioRouteMessage {
  unknown,
  bluetoothHeadset,
  wiredHeadset,
  speaker,
  earpiece,
}

/// How the microphone opens: voice detector or push to talk.
enum TalkModeMessage { voice, pushToTalk }

/// How easily the voice detector opens the microphone.
enum VadSensitivityMessage { low, medium, high }

/// Wi-Fi state as seen by the platform layer.
enum WifiStateMessage { unknown, disconnected, connected }

class RoomConfigMessage {
  RoomConfigMessage({
    required this.role,
    required this.displayName,
    required this.controlPort,
    required this.audioPort,
    required this.bitrateBps,
    required this.echoMode,
    required this.talkMode,
    required this.vadSensitivity,
    this.hostIp,
  });

  RoomRoleMessage role;

  /// Host IPv4 address; null when this phone is the host.
  String? hostIp;
  String displayName;
  int controlPort;
  int audioPort;
  int bitrateBps;

  /// Host only: return every audio packet to its sender (round-trip test).
  bool echoMode;

  /// How the microphone opens when the room starts (Dart changes it later
  /// through FFI).
  TalkModeMessage talkMode;

  /// The voice detector's sensitivity when the room starts.
  VadSensitivityMessage vadSensitivity;
}

class PlatformCapabilitiesMessage {
  PlatformCapabilitiesMessage({
    required this.canHostRoom,
    required this.supportsGatewayDiscovery,
    required this.supportsHotspotSettings,
    required this.supportsBatteryExemption,
  });

  bool canHostRoom;
  bool supportsGatewayDiscovery;
  bool supportsHotspotSettings;
  bool supportsBatteryExemption;
}

class PlatformInfoMessage {
  PlatformInfoMessage({
    required this.osName,
    required this.osVersion,
    required this.apiLevel,
    required this.manufacturer,
    required this.model,
    required this.capabilities,
  });

  /// "android" or "ios".
  String osName;

  /// Human readable OS version, e.g. "17".
  String osVersion;

  /// Android SDK_INT; on iOS the major OS version.
  int apiLevel;
  String manufacturer;
  String model;
  PlatformCapabilitiesMessage capabilities;
}

class ActiveRoomMessage {
  ActiveRoomMessage({required this.config, required this.muted});

  RoomConfigMessage config;
  bool muted;
}

class PlatformStateMessage {
  PlatformStateMessage({
    required this.serviceRunning,
    required this.audioRoute,
    required this.wifiState,
    required this.systemCall,
  });

  bool serviceRunning;
  AudioRouteMessage audioRoute;
  WifiStateMessage wifiState;

  /// The room is registered as a call with the system (Telecom), so headsets
  /// see a real call; false when it is only routed.
  bool systemCall;
}

@HostApi()
abstract class VoicePlatformHostApi {
  PlatformInfoMessage getPlatformInfo();

  /// Starts the room session (inside the foreground service from phase 4).
  @async
  void startRoom(RoomConfigMessage config);

  @async
  void stopRoom();

  void setMute(bool muted);

  /// Opens the system hotspot (tethering) settings screen.
  void openHotspotSettings();

  /// Asks the user to exempt the app from battery optimizations.
  /// Returns whether the app is exempt afterwards.
  @async
  bool requestBatteryExemption();

  void setKeepScreenOn(bool enabled);

  /// The room owned by the running service, if any (used when the UI reopens).
  ActiveRoomMessage? getActiveRoom();
}

@EventChannelApi()
abstract class VoicePlatformEventApi {
  PlatformStateMessage watchPlatformState();
}
