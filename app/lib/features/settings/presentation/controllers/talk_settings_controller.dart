import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/settings_providers.dart';

/// The talk settings on screen, and whether the last change could not be
/// stored (it still applies to the running room).
final class TalkSettingsState extends Equatable {
  const new(this.settings, {this.saveFailed = false});

  final TalkSettings settings;
  final bool saveFailed;

  @override
  List<Object?> get props => [settings, saveFailed];
}

/// Loads the rider's talk settings and changes them: the screen shows the
/// new choice at once, while it is applied to the room and stored.
final class TalkSettingsController extends AsyncNotifier<TalkSettingsState> {
  @override
  Future<TalkSettingsState> build() async => TalkSettingsState(
    await ref.read(settingsRepositoryProvider).loadTalkSettings(),
  );

  Future<void> setMode(TalkMode mode) =>
      _change((settings) => settings.copyWith(mode: mode));

  Future<void> setSensitivity(VadSensitivity sensitivity) =>
      _change((settings) => settings.copyWith(sensitivity: sensitivity));

  Future<void> _change(TalkSettings Function(TalkSettings) edit) async {
    final current = state.value;
    if (current == null) {
      return; // still loading: there is nothing to change yet
    }
    final next = edit(current.settings);
    state = AsyncData(TalkSettingsState(next));
    final result = await ref.read(updateTalkSettingsProvider).call(next);
    if (!ref.mounted) {
      return;
    }
    if (result is Failure) {
      state = AsyncData(TalkSettingsState(next, saveFailed: true));
    }
  }
}
