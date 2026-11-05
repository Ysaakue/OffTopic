import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/settings_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Talk mode (voice detector or push to talk) and, in voice mode, the
/// detector's sensitivity. Changes apply to the running room at once.
class TalkSettingsPanel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(talkSettingsControllerProvider).value;
    if (state == null) {
      return const SizedBox.shrink(); // loading takes a few milliseconds
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(talkSettingsControllerProvider.notifier);
    final settings = state.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.talkModeLabel, style: textTheme.titleMedium),
        const SizedBox(height: AppDimensions.spacingSmall),
        SegmentedButton<TalkMode>(
          key: const Key('talk.mode'),
          segments: [
            ButtonSegment(
              value: TalkMode.voice,
              label: Text(l10n.talkModeVoice),
            ),
            ButtonSegment(
              value: TalkMode.pushToTalk,
              label: Text(l10n.talkModePushToTalk),
            ),
          ],
          selected: {settings.mode},
          onSelectionChanged: (selection) =>
              unawaited(controller.setMode(selection.single)),
        ),
        if (settings.mode == TalkMode.voice) ...[
          const SizedBox(height: AppDimensions.spacingMedium),
          Text(l10n.vadSensitivityLabel, style: textTheme.titleMedium),
          const SizedBox(height: AppDimensions.spacingSmall),
          SegmentedButton<VadSensitivity>(
            key: const Key('talk.sensitivity'),
            segments: [
              ButtonSegment(
                value: VadSensitivity.low,
                label: Text(l10n.vadSensitivityLow),
              ),
              ButtonSegment(
                value: VadSensitivity.medium,
                label: Text(l10n.vadSensitivityMedium),
              ),
              ButtonSegment(
                value: VadSensitivity.high,
                label: Text(l10n.vadSensitivityHigh),
              ),
            ],
            selected: {settings.sensitivity},
            onSelectionChanged: (selection) =>
                unawaited(controller.setSensitivity(selection.single)),
          ),
        ],
        if (state.saveFailed) ...[
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(
            l10n.talkSettingsSaveFailed,
            key: const Key('talk.saveFailed'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
