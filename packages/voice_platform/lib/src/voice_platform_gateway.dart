import 'package:voice_platform/src/models/active_room.dart';
import 'package:voice_platform/src/models/platform_info.dart';
import 'package:voice_platform/src/models/platform_state.dart';
import 'package:voice_platform/src/models/room_config.dart';

// Every method throws a VoicePlatformException when the platform fails.
// Callers depend on the narrowest interface they need (interface segregation).

/// Static device facts.
abstract interface class PlatformInfoSource {
  /// Describes the device, OS and platform capabilities.
  Future<PlatformInfo> getPlatformInfo();
}

/// Lifecycle of the room owned by the platform service.
abstract interface class RoomServiceControl {
  /// Starts the foreground service and the room session.
  Future<void> startRoom(RoomConfig config);

  /// Leaves the room and stops the service.
  Future<void> stopRoom();

  /// Mutes or unmutes the local microphone.
  Future<void> setMute({required bool muted});

  /// The running room, if any (used when the UI reopens).
  Future<ActiveRoom?> getActiveRoom();
}

/// System screens and prompts the user must act on.
abstract interface class SystemSettingsLauncher {
  /// Opens the hotspot (tethering) settings screen.
  Future<void> openHotspotSettings();

  /// Asks to exempt the app from battery optimizations; returns whether it is
  /// exempt afterwards.
  Future<bool> requestBatteryExemption();
}

/// Screen behavior while the room is visible.
abstract interface class ScreenControl {
  /// Keeps the screen awake when [enabled].
  Future<void> setKeepScreenOn({required bool enabled});
}

/// Live platform state.
abstract interface class PlatformStateSource {
  /// Emits the current state on listen and every change afterwards.
  Stream<PlatformState> watchPlatformState();
}

/// Everything the app needs from the host platform.
abstract interface class VoicePlatformGateway
    implements
        PlatformInfoSource,
        RoomServiceControl,
        SystemSettingsLauncher,
        ScreenControl,
        PlatformStateSource;
