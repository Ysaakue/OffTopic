import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';
import 'package:offtopic/features/room/presentation/widgets/host_address_panel.dart';
import 'package:offtopic/features/room/room_providers.dart';

import '../../../../helpers/fake_local_network_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/room_fixtures.dart';

void main() {
  late FakeLocalNetworkRepository network;

  setUp(() => network = FakeLocalNetworkRepository());

  Future<void> pumpPanel(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpLocalized(
      Scaffold(body: HostAddressPanel(key: UniqueKey())),
      locale: locale ?? const Locale('en'),
      overrides: [localNetworkRepositoryProvider.overrideWithValue(network)],
    );
    await tester.pump();
  }

  testWidgets('lists every address with its network', (tester) async {
    network.result = Success([
      hotspotAddress,
      wifiAddress,
      LocalAddress(
        kind: LocalNetworkKind.other,
        address: HostAddress.tryParse('10.0.2.15')!,
      ),
    ]);

    await pumpPanel(tester);

    expect(
      find.text('Your IP: the other riders type it to join'),
      findsOneWidget,
    );
    expect(find.text('Hotspot: 192.168.43.1'), findsOneWidget);
    expect(find.text('Wi-Fi: 192.168.1.20'), findsOneWidget);
    expect(find.text('Other network: 10.0.2.15'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('hostAddress.entry.0'))).data,
      'Hotspot: 192.168.43.1',
    );
  });

  testWidgets('asks for the hotspot without a local network', (tester) async {
    await pumpPanel(tester);

    expect(
      find.text("No local network yet: turn on this phone's hotspot."),
      findsOneWidget,
    );
  });

  testWidgets('says when the phone cannot list its addresses', (tester) async {
    network.result = const Failure(LocalNetworkFailure('getifaddrs'));

    await pumpPanel(tester);

    expect(find.text("Could not read this phone's IP."), findsOneWidget);
  });

  testWidgets('reads the addresses again on request', (tester) async {
    await pumpPanel(tester);
    network.result = Success([hotspotAddress]);

    await tester.tap(find.byKey(const Key('hostAddress.refresh')));
    await tester.pump();
    await tester.pump();

    expect(network.reads, 2);
    expect(find.text('Hotspot: 192.168.43.1'), findsOneWidget);
  });

  testWidgets('reads the addresses again when the app comes back', (
    tester,
  ) async {
    await pumpPanel(tester);
    network.result = Success([hotspotAddress]);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(network.reads, 2);
    expect(find.text('Hotspot: 192.168.43.1'), findsOneWidget);
  });

  testWidgets('speaks Portuguese', (tester) async {
    network.result = Success([wifiAddress]);

    await pumpPanel(tester, locale: const Locale('pt'));

    expect(find.text('Wi-Fi: 192.168.1.20'), findsOneWidget);
    expect(find.text('Atualizar IP'), findsOneWidget);
  });
}
