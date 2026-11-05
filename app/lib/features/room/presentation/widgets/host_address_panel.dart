import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// The host phone's own IP addresses, which the other riders type to join.
///
/// They are read again when the app comes back to the foreground (the rider
/// usually turns the hotspot on in the system settings) and on request.
class HostAddressPanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HostAddressPanel> createState() => _HostAddressPanelState();
}

class _HostAddressPanelState extends ConsumerState<HostAddressPanel> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(hostAddressesProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final result = ref.watch(hostAddressesProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.hostAddressTitle, style: textTheme.titleMedium),
        ...switch (result) {
          null => const <Widget>[],
          Failure() => [
            Text(
              l10n.hostAddressUnavailable,
              key: const Key('hostAddress.unavailable'),
            ),
          ],
          Success(value: final addresses) when addresses.isEmpty => [
            Text(l10n.hostAddressNone, key: const Key('hostAddress.none')),
          ],
          Success(value: final addresses) => [
            for (final (index, local) in addresses.indexed)
              Text(
                l10n.hostAddressEntry(
                  _networkName(l10n, local.kind),
                  local.address.value,
                ),
                key: Key('hostAddress.entry.$index'),
                style: textTheme.headlineSmall,
              ),
          ],
        },
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('hostAddress.refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.hostAddressRefresh),
          ),
        ),
      ],
    );
  }

  static String _networkName(AppLocalizations l10n, LocalNetworkKind kind) =>
      switch (kind) {
        LocalNetworkKind.hotspot => l10n.hostAddressHotspot,
        LocalNetworkKind.wifi => l10n.hostAddressWifi,
        LocalNetworkKind.other => l10n.hostAddressOther,
      };
}
