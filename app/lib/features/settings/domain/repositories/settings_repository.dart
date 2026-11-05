import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

/// The rider's preferences, stored on the phone.
abstract interface class SettingsRepository {
  /// The stored talk settings; the defaults when nothing (or nothing valid)
  /// was stored, so the room can always start.
  Future<TalkSettings> loadTalkSettings();

  /// Stores [settings] for the next rooms.
  Future<Result<void>> saveTalkSettings(TalkSettings settings);
}
