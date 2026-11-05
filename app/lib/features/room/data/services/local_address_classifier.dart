import 'package:offtopic/core/network/local_interfaces.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';

/// Decides which of this phone's addresses the other riders can reach, and
/// on which kind of network, from the interface names Android uses.
final class LocalAddressClassifier {
  const new();

  /// Hotspot interfaces: `ap0`, `swlan0` (Samsung), `softap0`, the bridged
  /// dual-band `ap_br_wlan1`, and a second Wi-Fi radio (`wlan1`, `wlan2`).
  static final _hotspot = RegExp(r'^(ap\d|ap_br_|swlan\d|softap\d|wlan[1-9])');

  /// The Wi-Fi client interface.
  static final _wifi = RegExp(r'^wlan0$');

  /// Mobile data, VPN, Wi-Fi Direct and virtual interfaces, which can carry
  /// private addresses the riders cannot reach.
  static const _unreachable = [
    'ccmni',
    'clat',
    'dummy',
    'ipsec',
    'p2p',
    'ppp',
    'rmnet',
    'tun',
    'v4-',
    'wwan',
  ];

  static const _classA = 10;
  static const _classB = 172;
  static const _classBFirst = 16;
  static const _classBLast = 31;
  static const _classC = 192;
  static const _classCSecond = 168;

  /// The addresses of [interfaces] the riders can reach, hotspot first, then
  /// Wi-Fi, then other local networks, each once.
  List<LocalAddress> classifyAll(List<LocalInterface> interfaces) {
    final reachable = {
      for (final interface in interfaces)
        for (final ipv4 in interface.ipv4) ?classify(interface.name, ipv4),
    };
    return [
      for (final kind in LocalNetworkKind.values)
        ...reachable.where((address) => address.kind == kind),
    ];
  }

  /// The address [ipv4] of the interface [name], or null when the riders
  /// cannot use it: not a private (RFC 1918) address, or a mobile data, VPN
  /// or virtual interface.
  LocalAddress? classify(String name, String ipv4) {
    final address = HostAddress.tryParse(ipv4);
    if (address == null || !_isPrivate(address)) {
      return null;
    }
    final interface = name.toLowerCase();
    if (_unreachable.any(interface.startsWith)) {
      return null;
    }
    final kind = _hotspot.hasMatch(interface)
        ? LocalNetworkKind.hotspot
        : _wifi.hasMatch(interface)
        ? LocalNetworkKind.wifi
        : LocalNetworkKind.other;
    return LocalAddress(kind: kind, address: address);
  }

  static bool _isPrivate(HostAddress address) {
    final octets = address.value.split('.').map(int.parse).toList();
    final [first, second, ...] = octets;
    return first == _classA ||
        (first == _classB && second >= _classBFirst && second <= _classBLast) ||
        (first == _classC && second == _classCSecond);
  }
}
