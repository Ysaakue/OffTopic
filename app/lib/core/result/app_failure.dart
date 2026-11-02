import 'package:equatable/equatable.dart';

/// A failure the domain and presentation layers understand.
///
/// The data layer converts every infrastructure exception into one of these,
/// so no package exception ever reaches a widget.
sealed class AppFailure extends Equatable implements Exception {
  const new(this.message);

  /// Technical detail for logs; never shown to the rider as is.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// The native voice core failed or is unavailable.
final class CoreFailure extends AppFailure {
  const new(super.message);
}

/// The platform layer (Kotlin / Swift) failed.
final class PlatformFailure extends AppFailure {
  const new({required this.code, String? message}) : super(message ?? code);

  /// Machine readable code reported by the platform.
  final String code;

  @override
  List<Object?> get props => [code, message];
}

/// A runtime permission the room needs was not granted.
final class PermissionFailure extends AppFailure {
  const new({required this.permanentlyDenied})
    : super('A required permission was not granted.');

  /// The system will not ask again; only the app settings can grant it.
  final bool permanentlyDenied;

  @override
  List<Object?> get props => [message, permanentlyDenied];
}

/// Why starting or controlling the room failed.
enum RoomFailureReason {
  /// A room is already running.
  alreadyActive,

  /// The voice core rejected the configuration.
  invalidConfig,

  /// The microphone or the speaker could not be opened.
  audioDevice,

  /// The network socket could not be opened.
  network,

  /// The platform or the core failed in another way.
  unavailable,
}

/// Starting, stopping or controlling the room failed.
final class RoomFailure extends AppFailure {
  const new(this.reason, super.message);

  /// What went wrong, for the message shown to the rider.
  final RoomFailureReason reason;

  @override
  List<Object?> get props => [reason, message];
}
