import 'package:equatable/equatable.dart';

/// The link to the other phone came up or went down.
final class RoomLink extends Equatable {
  const new({required this.up, required this.peer});

  /// Whether the peer is reachable.
  final bool up;

  /// The peer endpoint, "a.b.c.d:port".
  final String peer;

  @override
  List<Object?> get props => [up, peer];
}
