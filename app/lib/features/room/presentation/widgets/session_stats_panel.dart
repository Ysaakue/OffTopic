import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Link state and the 4 Hz statistics of the running test.
class SessionStatsPanel extends ConsumerWidget {
  const new({super.key});

  static const _decimals = 1;
  static const _percent = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(sessionStatsProvider).value;
    final link = ref.watch(roomLinkProvider).value;

    return Column(
      key: const Key('audioTest.stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(
          _linkText(l10n, stats, link),
          key: const Key('audioTest.link'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (stats != null) ..._rows(l10n, stats),
      ],
    );
  }

  static String _linkText(
    AppLocalizations l10n,
    SessionStats? stats,
    RoomLink? link,
  ) {
    if (link != null && !link.up) {
      return l10n.audioTestLinkLost(link.peer);
    }
    if (link != null && (stats?.linkUp ?? true)) {
      return l10n.audioTestLinkUp(link.peer);
    }
    return l10n.audioTestLinkWaiting;
  }

  static List<Widget> _rows(AppLocalizations l10n, SessionStats stats) {
    final rtt = stats.rttMs;
    return [
      _StatRow(
        label: l10n.audioTestStatLoss,
        value: l10n.audioTestValuePercent(
          stats.lossPct.toStringAsFixed(_decimals),
        ),
      ),
      _StatRow(
        label: l10n.audioTestStatJitter,
        value: l10n.audioTestValueMs(stats.jitterMs.toStringAsFixed(_decimals)),
      ),
      _StatRow(
        label: l10n.audioTestStatBuffer,
        value: l10n.audioTestValueBuffer(
          '${stats.jitterBufferMs}',
          '${stats.jitterTargetMs}',
        ),
      ),
      _StatRow(
        label: l10n.audioTestStatRtt,
        value: rtt == null
            ? l10n.audioTestValueUnknown
            : l10n.audioTestValueMs('$rtt'),
      ),
      _StatRow(
        label: l10n.audioTestStatPackets,
        value: l10n.audioTestValuePair(
          '${stats.packetsSent}',
          '${stats.packetsReceived}',
        ),
      ),
      _StatRow(
        label: l10n.audioTestStatLostLate,
        value: l10n.audioTestValuePair(
          '${stats.packetsLost}',
          '${stats.packetsLate}',
        ),
      ),
      _StatRow(
        label: l10n.audioTestStatRecovered,
        value: l10n.audioTestValuePair(
          '${stats.fecRecovered}',
          '${stats.concealedFrames}',
        ),
      ),
      _StatRow(
        label: l10n.audioTestStatUnderruns,
        value: '${stats.playoutUnderruns}',
      ),
      _StatRow(
        label: l10n.audioTestStatInput,
        value: l10n.audioTestValuePercent(
          '${(stats.inputLevel * _percent).round()}',
        ),
      ),
      LinearProgressIndicator(
        key: const Key('audioTest.inputLevel'),
        value: stats.inputLevel,
      ),
    ];
  }
}

class _StatRow extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSmall),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
