import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/room/data/services/local_address_classifier.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';

void main() {
  const classifier = LocalAddressClassifier();

  LocalAddress local(LocalNetworkKind kind, String ipv4) =>
      LocalAddress(kind: kind, address: HostAddress.tryParse(ipv4)!);

  group('classify', () {
    for (final (name, ipv4, kind) in [
      ('ap0', '192.168.43.1', LocalNetworkKind.hotspot),
      ('swlan0', '192.168.200.150', LocalNetworkKind.hotspot),
      ('softap0', '10.42.0.1', LocalNetworkKind.hotspot),
      ('ap_br_wlan1', '192.168.118.20', LocalNetworkKind.hotspot),
      ('wlan1', '192.168.43.1', LocalNetworkKind.hotspot),
      ('wlan2', '172.20.10.1', LocalNetworkKind.hotspot),
      ('wlan0', '192.168.1.20', LocalNetworkKind.wifi),
      ('WLAN0', '192.168.1.20', LocalNetworkKind.wifi),
      ('eth0', '10.0.2.15', LocalNetworkKind.other),
      ('rndis0', '192.168.42.129', LocalNetworkKind.other),
      ('wlan10', '172.16.0.1', LocalNetworkKind.hotspot),
    ]) {
      test('$name $ipv4 is $kind', () {
        expect(classifier.classify(name, ipv4), local(kind, ipv4));
      });
    }

    for (final (name, ipv4, why) in [
      ('rmnet_data0', '10.12.0.7', 'mobile data (Qualcomm)'),
      ('ccmni1', '10.120.5.9', 'mobile data (MediaTek)'),
      ('v4-rmnet_data2', '192.0.0.4', 'IPv4 over IPv6 mobile data'),
      ('clat4', '192.168.0.4', 'IPv4 over IPv6 translation'),
      ('tun0', '10.8.0.2', 'VPN'),
      ('ppp0', '10.64.64.64', 'dial-up modem'),
      ('ipsec0', '10.9.0.2', 'IPsec VPN'),
      ('p2p-wlan0-0', '192.168.49.1', 'Wi-Fi Direct'),
      ('wwan0', '10.33.1.2', 'mobile data modem'),
      ('dummy0', '10.0.0.1', 'virtual interface'),
      ('wlan0', '127.0.0.1', 'loopback'),
      ('wlan0', '169.254.10.20', 'link-local'),
      ('wlan0', '100.64.1.2', 'carrier-grade NAT'),
      ('wlan0', '8.8.8.8', 'public address'),
      ('wlan0', '172.15.255.1', 'just below 172.16/12'),
      ('wlan0', '172.32.0.1', 'just above 172.16/12'),
      ('wlan0', '192.169.0.1', 'next to 192.168/16'),
      ('wlan0', '11.0.0.1', 'next to 10/8'),
      ('wlan0', 'fe80::1', 'IPv6'),
    ]) {
      test('skips $name $ipv4 ($why)', () {
        expect(classifier.classify(name, ipv4), isNull);
      });
    }

    test('keeps both edges of 172.16/12', () {
      expect(classifier.classify('wlan0', '172.16.0.1'), isNotNull);
      expect(classifier.classify('wlan0', '172.31.255.254'), isNotNull);
    });
  });

  group('classifyAll', () {
    test('puts the hotspot first, then Wi-Fi, then the rest', () {
      final addresses = classifier.classifyAll([
        (name: 'eth0', ipv4: ['10.0.2.15']),
        (name: 'wlan0', ipv4: ['192.168.1.20']),
        (name: 'rmnet_data0', ipv4: ['10.12.0.7']),
        (name: 'swlan0', ipv4: ['192.168.43.1', '192.168.44.1']),
      ]);

      expect(addresses, [
        local(LocalNetworkKind.hotspot, '192.168.43.1'),
        local(LocalNetworkKind.hotspot, '192.168.44.1'),
        local(LocalNetworkKind.wifi, '192.168.1.20'),
        local(LocalNetworkKind.other, '10.0.2.15'),
      ]);
    });

    test('lists an address once', () {
      final addresses = classifier.classifyAll([
        (name: 'ap0', ipv4: ['192.168.43.1', '192.168.43.1']),
      ]);

      expect(addresses, [local(LocalNetworkKind.hotspot, '192.168.43.1')]);
    });

    test('is empty without a local network', () {
      expect(
        classifier.classifyAll([
          (name: 'lo', ipv4: ['127.0.0.1']),
          (name: 'rmnet_data0', ipv4: ['10.12.0.7']),
          (name: 'wlan0', ipv4: []),
        ]),
        isEmpty,
      );
      expect(classifier.classifyAll([]), isEmpty);
    });
  });
}
