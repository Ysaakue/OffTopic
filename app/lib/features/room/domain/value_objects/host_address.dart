import 'package:equatable/equatable.dart';

/// The IPv4 address of the host phone, as typed by the rider.
///
/// Same rules as the core (docs/PROTOCOL.md): a dotted quad that is not
/// 0.0.0.0, the broadcast address or multicast.
final class HostAddress extends Equatable {
  const new _(this.value);

  /// The address, or null when [input] (trimmed) is not a valid unicast IPv4.
  static HostAddress? tryParse(String input) {
    final text = input.trim();
    final match = _dottedQuad.firstMatch(text);
    if (match == null) {
      return null;
    }
    final octets = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
    if (octets.any((octet) => octet > _maxOctet) ||
        octets.every((octet) => octet == 0) ||
        octets.every((octet) => octet == _maxOctet) ||
        (octets.first >= _firstMulticast && octets.first <= _lastMulticast)) {
      return null;
    }
    return HostAddress._(text);
  }

  static final _dottedQuad = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );
  static const _maxOctet = 255;
  static const _firstMulticast = 224;
  static const _lastMulticast = 239;

  /// The dotted quad, e.g. "192.168.43.1".
  final String value;

  @override
  List<Object?> get props => [value];
}
