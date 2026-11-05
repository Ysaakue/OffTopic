import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/core/storage/key_value_store.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';

/// [SettingsRepository] over a [KeyValueStore]. Enum values are stored by
/// name, so reordering them never changes a stored preference; an unknown
/// or unreadable value falls back to its default.
final class SettingsRepositoryImpl implements SettingsRepository {
  const new(this._store);

  static const talkModeKey = 'talk.mode';
  static const vadSensitivityKey = 'talk.vadSensitivity';

  final KeyValueStore _store;

  @override
  Future<TalkSettings> loadTalkSettings() async {
    const defaults = TalkSettings();
    return TalkSettings(
      mode: _byName(TalkMode.values, await _read(talkModeKey)) ?? defaults.mode,
      sensitivity:
          _byName(VadSensitivity.values, await _read(vadSensitivityKey)) ??
          defaults.sensitivity,
    );
  }

  @override
  Future<Result<void>> saveTalkSettings(TalkSettings settings) async {
    try {
      await _store.write(talkModeKey, settings.mode.name);
      await _store.write(vadSensitivityKey, settings.sensitivity.name);
      return const Success(null);
    } on Exception catch (exception) {
      return Failure(StorageFailure(exception.toString()));
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _store.read(key);
    } on Exception {
      return null; // unreadable: the default applies
    }
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) =>
      values.where((value) => value.name == name).firstOrNull;
}
