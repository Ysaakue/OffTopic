import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/home/home_providers.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/settings_providers.dart';

/// Builds the report of the current room (or of the last one, after it
/// ended) from the room's state, statistics and events. Null before the
/// first room.
class SessionReportController extends Notifier<SessionReport?> {
  @override
  SessionReport? build() {
    ref
      ..listen(audioTestControllerProvider, _roomChanged)
      ..listen(sessionStatsProvider, (_, next) {
        final stats = next.value;
        if (stats != null && _running) {
          _update((report) => report.withStats(stats));
        }
      })
      ..listen(roomAudioProvider, (_, next) {
        final audio = next.value;
        if (audio != null && _running) {
          _update((report) => report.withAudio(audio));
        }
      })
      ..listen(roomLinkProvider, (_, next) {
        final link = next.value;
        if (link != null && _running) {
          _update((report) => report.withLink(link));
        }
      })
      ..listen(talkSettingsControllerProvider, (_, next) {
        final talk = next.value?.settings;
        if (talk != null && _running) {
          _update((report) => report.withTalk(talk));
        }
      });
    return null;
  }

  bool get _running => state != null && state!.endedAt == null;

  void _roomChanged(AudioTestState? previous, AudioTestState next) {
    final now = ref.read(clockProvider)();
    if (next is AudioTestActive && previous is! AudioTestActive) {
      state = SessionReport(
        request: next.request,
        talk:
            ref.read(talkSettingsControllerProvider).value?.settings ??
            const TalkSettings(),
        startedAt: now,
      );
      unawaited(_addAppInfo());
    } else if (previous is AudioTestActive && next is! AudioTestActive) {
      _update((report) => report.ended(now));
    }
  }

  Future<void> _addAppInfo() async {
    final result = await ref.read(getAppInfoProvider).call();
    if (!ref.mounted) {
      return;
    }
    if (result case Success(:final value)) {
      _update((report) => report.withAppInfo(value));
    }
  }

  void _update(SessionReport Function(SessionReport) change) {
    final report = state;
    if (report != null) {
      state = change(report);
    }
  }
}
