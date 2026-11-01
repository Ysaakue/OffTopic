import 'package:equatable/equatable.dart';
import 'package:voice_platform/src/models/platform_capabilities.dart';

/// Static facts about the device and its operating system.
final class PlatformInfo extends Equatable {
  /// Creates the platform description.
  const new({
    required this.osName,
    required this.osVersion,
    required this.apiLevel,
    required this.manufacturer,
    required this.model,
    required this.capabilities,
  });

  /// "android" or "ios".
  final String osName;

  /// Human readable OS version, e.g. "17".
  final String osVersion;

  /// Android SDK level; on iOS the major OS version.
  final int apiLevel;

  /// Device manufacturer, used for battery guidance (e.g. "Xiaomi").
  final String manufacturer;

  /// Device model.
  final String model;

  /// What this platform supports.
  final PlatformCapabilities capabilities;

  @override
  List<Object?> get props => [
    osName,
    osVersion,
    apiLevel,
    manufacturer,
    model,
    capabilities,
  ];
}
