import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/theme/app_dimensions.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/presentation/widgets/audio_test_form.dart';
import 'package:offtopic/features/room/presentation/widgets/failure_message.dart';
import 'package:offtopic/features/room/presentation/widgets/permission_denied_view.dart';
import 'package:offtopic/features/room/presentation/widgets/session_stats_panel.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Phase 1: two phones, the host IP typed by hand, audio over the speaker or
/// a wired headset, and the statistics needed to judge the call.
class AudioTestScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(audioTestControllerProvider);
    final controller = ref.read(audioTestControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.audioTestTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spacingMedium),
          children: [
            if (state case AudioTestPermissionDenied(:final permanently))
              PermissionDeniedView(
                permanently: permanently,
                onOpenSettings: controller.openSettings,
                onDismiss: controller.dismiss,
              )
            else ...[
              AudioTestForm(
                enabled: state is AudioTestIdle || state is AudioTestFailed,
                running: state is AudioTestActive,
                onStart: controller.start,
                onStop: controller.stop,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                _status(l10n, state),
                key: const Key('audioTest.status'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state case AudioTestFailed(:final failure))
                FailureMessage(failure: failure),
              if (state is AudioTestActive) const SessionStatsPanel(),
            ],
          ],
        ),
      ),
    );
  }

  static String _status(AppLocalizations l10n, AudioTestState state) =>
      switch (state) {
        AudioTestStarting() => l10n.audioTestStatusStarting,
        AudioTestActive() => l10n.audioTestStatusActive,
        AudioTestStopping() => l10n.audioTestStatusStopping,
        AudioTestIdle() ||
        AudioTestFailed() ||
        AudioTestPermissionDenied() => l10n.audioTestStatusIdle,
      };
}
