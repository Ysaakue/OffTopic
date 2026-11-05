import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';

/// Changes the talk settings: applied to the running room at once (the rider
/// may switch to push to talk mid-ride) and stored for the next rooms.
final class UpdateTalkSettings {
  const new({required this._settings, required this._rooms});

  final SettingsRepository _settings;
  final RoomRepository _rooms;

  /// The first failure, if any; the live change is attempted even when
  /// storing fails.
  Future<Result<void>> call(TalkSettings talk) async {
    final applied = _rooms.applyTalkSettings(talk);
    final saved = await _settings.saveTalkSettings(talk);
    return applied is Failure ? applied : saved;
  }
}
