import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/data/repositories/local_network_repository_impl.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  test('classifies the interfaces, hotspot first', () async {
    final repository = LocalNetworkRepositoryImpl(
      list: () async => [
        (name: 'wlan0', ipv4: ['192.168.1.20']),
        (name: 'rmnet_data0', ipv4: ['10.12.0.7']),
        (name: 'ap0', ipv4: ['192.168.43.1']),
      ],
    );

    expect(
      await repository.localAddresses(),
      Success<List<LocalAddress>>([hotspotAddress, wifiAddress]),
    );
  });

  test('turns a system error into a failure', () async {
    final repository = LocalNetworkRepositoryImpl(
      list: () async => throw const SocketException('getifaddrs failed'),
    );

    expect(
      await repository.localAddresses(),
      const Failure<List<LocalAddress>>(
        LocalNetworkFailure('getifaddrs failed'),
      ),
    );
  });
}
