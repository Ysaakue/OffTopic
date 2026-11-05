import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/network/local_interfaces.dart';

void main() {
  test('lists only IPv4 addresses of named interfaces', () async {
    final interfaces = await listLocalInterfaces();

    for (final interface in interfaces) {
      expect(interface.name, isNotEmpty);
      for (final address in interface.ipv4) {
        expect(
          InternetAddress.tryParse(address)?.type,
          InternetAddressType.IPv4,
          reason: '${interface.name}: $address',
        );
      }
    }
  });
}
