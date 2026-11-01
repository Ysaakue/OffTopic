import 'package:equatable/equatable.dart';
import 'package:voice_platform/src/models/audio_route.dart';
import 'package:voice_platform/src/models/wifi_state.dart';

/// Live state of the platform layer.
final class PlatformState extends Equatable {
  /// Creates a state snapshot.
  const new({
    required this.serviceRunning,
    required this.audioRoute,
    required this.wifiState,
  });

  /// State before any room is started.
  static const idle = PlatformState(
    serviceRunning: false,
    audioRoute: AudioRoute.unknown,
    wifiState: WifiState.unknown,
  );

  /// Whether the foreground service that owns the room is running.
  final bool serviceRunning;

  /// Current audio route.
  final AudioRoute audioRoute;

  /// Current Wi-Fi state.
  final WifiState wifiState;

  @override
  List<Object?> get props => [serviceRunning, audioRoute, wifiState];
}
