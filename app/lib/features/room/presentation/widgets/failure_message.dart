import 'package:flutter/material.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/l10n/generated/app_localizations.dart';

/// Explains a failed start or stop in the rider's words.
class FailureMessage extends StatelessWidget {
  const new({required this.failure, super.key});

  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      _message(l10n),
      key: const Key('audioTest.error'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }

  String _message(AppLocalizations l10n) => switch (failure) {
    RoomFailure(reason: RoomFailureReason.alreadyActive) =>
      l10n.audioTestErrorAlreadyActive,
    RoomFailure(reason: RoomFailureReason.invalidConfig) =>
      l10n.audioTestErrorInvalidConfig,
    RoomFailure(reason: RoomFailureReason.audioDevice) =>
      l10n.audioTestErrorAudioDevice,
    RoomFailure(reason: RoomFailureReason.network) =>
      l10n.audioTestErrorNetwork,
    _ => l10n.audioTestErrorUnavailable,
  };
}
