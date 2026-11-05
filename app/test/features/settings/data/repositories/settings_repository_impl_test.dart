import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

import '../../../../helpers/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore store;
  late SettingsRepositoryImpl repository;

  setUp(() {
    store = FakeKeyValueStore();
    repository = SettingsRepositoryImpl(store);
  });

  test('loads the defaults when nothing was stored', () async {
    expect(await repository.loadTalkSettings(), const TalkSettings());
  });

  test('stores the settings by name and loads them back', () async {
    const settings = TalkSettings(
      mode: TalkMode.pushToTalk,
      sensitivity: VadSensitivity.high,
    );

    expect(
      await repository.saveTalkSettings(settings),
      const Success<void>(null),
    );

    expect(store.values, {
      SettingsRepositoryImpl.talkModeKey: 'pushToTalk',
      SettingsRepositoryImpl.vadSensitivityKey: 'high',
    });
    expect(await repository.loadTalkSettings(), settings);
  });

  test('falls back to the default for an unknown stored value', () async {
    store.values[SettingsRepositoryImpl.talkModeKey] = 'telepathy';
    store.values[SettingsRepositoryImpl.vadSensitivityKey] = 'low';

    expect(
      await repository.loadTalkSettings(),
      const TalkSettings(sensitivity: VadSensitivity.low),
    );
  });

  test('loads the defaults when the storage cannot be read', () async {
    store
      ..values[SettingsRepositoryImpl.talkModeKey] = 'pushToTalk'
      ..readError = Exception('locked');

    expect(await repository.loadTalkSettings(), const TalkSettings());
  });

  test('reports a storage failure when saving fails', () async {
    store.writeError = Exception('disk full');

    final result = await repository.saveTalkSettings(const TalkSettings());

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).failure, isA<StorageFailure>());
  });
}
