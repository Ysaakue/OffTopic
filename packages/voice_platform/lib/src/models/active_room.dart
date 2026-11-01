import 'package:equatable/equatable.dart';
import 'package:voice_platform/src/models/room_config.dart';

/// The room owned by the running platform service.
final class ActiveRoom extends Equatable {
  /// Creates the description of a running room.
  const new({required this.config, required this.muted});

  /// Configuration the room was started with.
  final RoomConfig config;

  /// Whether the local microphone is muted.
  final bool muted;

  @override
  List<Object?> get props => [config, muted];
}
