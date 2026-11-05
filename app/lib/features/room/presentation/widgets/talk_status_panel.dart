import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Where the room is heard (intercom, headset, speaker), whether the phone
/// treats it as a call, and whether the microphone is on the air.
class TalkStatusPanel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final audio = ref.watch(roomAudioProvider).value ?? const RoomAudio();
    final talking = ref.watch(talkingProvider).value ?? false;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.audioRouteLabel(_routeName(l10n, audio.route)),
          key: const Key('talk.route'),
          style: textTheme.titleMedium,
        ),
        Text(
          audio.systemCall
              ? l10n.audioCallModeSystem
              : l10n.audioCallModeDirect,
          key: const Key('talk.callMode'),
          style: textTheme.bodyMedium,
        ),
        Text(
          talking ? l10n.talkingOnAir : l10n.talkingQuiet,
          key: const Key('talk.talking'),
          style: textTheme.titleMedium?.copyWith(
            color: talking ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  static String _routeName(AppLocalizations l10n, AudioRoute route) =>
      switch (route) {
        AudioRoute.intercom => l10n.audioRouteIntercom,
        AudioRoute.headset => l10n.audioRouteHeadset,
        AudioRoute.speaker => l10n.audioRouteSpeaker,
        AudioRoute.earpiece => l10n.audioRouteEarpiece,
        AudioRoute.unknown => l10n.audioRouteUnknown,
      };
}
