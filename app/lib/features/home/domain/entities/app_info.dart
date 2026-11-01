import 'package:equatable/equatable.dart';

/// What the home screen shows about the app, the core and the phone.
final class AppInfo extends Equatable {
  const new({
    required this.coreVersion,
    required this.manufacturer,
    required this.model,
    required this.osName,
    required this.osVersion,
  });

  /// Version of the native voice core.
  final String coreVersion;

  final String manufacturer;
  final String model;

  /// "android" or "ios".
  final String osName;
  final String osVersion;

  @override
  List<Object?> get props => [
    coreVersion,
    manufacturer,
    model,
    osName,
    osVersion,
  ];
}
