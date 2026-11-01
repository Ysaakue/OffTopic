import 'package:equatable/equatable.dart';

/// What the current platform can do; the UI adapts to it instead of checking
/// the operating system.
final class PlatformCapabilities extends Equatable {
  /// Creates a capability set.
  const new({
    required this.canHostRoom,
    required this.supportsGatewayDiscovery,
    required this.supportsHotspotSettings,
    required this.supportsBatteryExemption,
  });

  /// Whether this phone can be the host (needs a hotspot).
  final bool canHostRoom;

  /// Whether the host IP can be found from the Wi-Fi default gateway.
  final bool supportsGatewayDiscovery;

  /// Whether the app can open the system hotspot settings.
  final bool supportsHotspotSettings;

  /// Whether the app can ask to be exempt from battery optimizations.
  final bool supportsBatteryExemption;

  @override
  List<Object?> get props => [
    canHostRoom,
    supportsGatewayDiscovery,
    supportsHotspotSettings,
    supportsBatteryExemption,
  ];
}
