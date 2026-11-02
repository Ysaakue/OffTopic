import 'package:equatable/equatable.dart';
import 'package:offtopic/features/room/domain/value_objects/display_name.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';

/// What the rider asked for: host a room or join one. The two cases are
/// separate types, so a client always has a host address and only a host can
/// use echo mode.
sealed class RoomRequest extends Equatable {
  const new({required this.name});

  /// Name of this rider.
  final DisplayName name;
}

/// Host the room on this phone.
final class HostRoomRequest extends RoomRequest {
  const new({required super.name, this.echoMode = false});

  /// Return every packet to its sender instead of sending the microphone,
  /// to measure the audio round trip.
  final bool echoMode;

  @override
  List<Object?> get props => [name, echoMode];
}

/// Join the room hosted at [host].
final class JoinRoomRequest extends RoomRequest {
  const new({required super.name, required this.host});

  /// The host phone.
  final HostAddress host;

  @override
  List<Object?> get props => [name, host];
}
