import 'package:equatable/equatable.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';

/// The kind of local network an address of this phone belongs to.
enum LocalNetworkKind {
  /// This phone's own hotspot: the network the riders join.
  hotspot,

  /// A Wi-Fi network this phone joined.
  wifi,

  /// Another local network (USB or Ethernet tethering, an emulator).
  other,
}

/// An IPv4 address of this phone on a local network, as the other riders
/// type it to join the room.
final class LocalAddress extends Equatable {
  const new({required this.kind, required this.address});

  final LocalNetworkKind kind;
  final HostAddress address;

  @override
  List<Object?> get props => [kind, address];
}
