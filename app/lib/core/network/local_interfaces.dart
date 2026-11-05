import 'dart:io';

/// One network interface of this phone and its IPv4 addresses.
typedef LocalInterface = ({String name, List<String> ipv4});

/// Lists this phone's network interfaces that have an IPv4 address.
typedef LocalInterfaceLister = Future<List<LocalInterface>> Function();

/// [LocalInterfaceLister] over `dart:io`. It throws a [SocketException] when
/// the system cannot list its interfaces.
Future<List<LocalInterface>> listLocalInterfaces() async => [
  for (final interface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  ))
    (
      name: interface.name,
      ipv4: [for (final address in interface.addresses) address.address],
    ),
];
