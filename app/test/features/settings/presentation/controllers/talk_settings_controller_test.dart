import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/storage/key_value_store.dart';
import 'package:offtopic/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:offtopic/features/settings/presentation/controllers/talk_settings_controller.dart';
import 'package:offtopic/features/settings/settings_providers.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';
import 'package:voice_platform/testing.dart';

import '../../../../helpers/fake_key_value_store.dart';

void main() {
  late FakeVoicePlatformGateway platform;
  late FakeVoiceCoreClient core;
  late FakeKeyValueStore store;
  late ProviderContainer container;

  setUp(() {
    platform = FakeVoicePlatformGateway();
    core = FakeVoiceCoreClient();
    store = FakeKeyValueStore();
    container = ProviderContainer(
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
        keyValueStoreProvider.overrideWithValue(store),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(platform.dispose());
  });

  TalkSettingsController controller() =>
      container.read(talkSettingsControllerProvider.notifier);
  Future<TalkSettingsState> loaded() =>
      container.read(talkSettingsControllerProvider.future);

  test('loads the stored settings', () async {
    store.values[SettingsRepositoryImpl.talkModeKey] = 'pushToTalk';

    expect(
      await loaded(),
      const TalkSettingsState(TalkSettings(mode: TalkMode.pushToTalk)),
    );
  });

  test('switches the talk mode, live and for the next rooms', () async {
    await loaded();

    await controller().setMode(TalkMode.pushToTalk);

    expect(
      container.read(talkSettingsControllerProvider).value,
      const TalkSettingsState(TalkSettings(mode: TalkMode.pushToTalk)),
    );
    expect(core.talkModes, [CoreTalkMode.pushToTalk]);
    expect(store.values[SettingsRepositoryImpl.talkModeKey], 'pushToTalk');
  });

  test('changes the sensitivity', () async {
    await loaded();

    await controller().setSensitivity(VadSensitivity.high);

    expect(core.vadSensitivities, [CoreVadSensitivity.high]);
    expect(store.values[SettingsRepositoryImpl.vadSensitivityKey], 'high');
  });

  test('keeps the change on screen when it cannot be stored', () async {
    await loaded();
    store.writeError = Exception('disk full');

    await controller().setSensitivity(VadSensitivity.low);

    expect(
      container.read(talkSettingsControllerProvider).value,
      const TalkSettingsState(
        TalkSettings(sensitivity: VadSensitivity.low),
        saveFailed: true,
      ),
    );
    expect(core.vadSensitivities, [CoreVadSensitivity.low]);
  });

  test('ignores a change before the settings are loaded', () async {
    final loading = Completer<void>();
    final slow = _SlowStore(loading.future);
    final waiting = ProviderContainer(
      overrides: [
        voicePlatformGatewayProvider.overrideWithValue(platform),
        voiceCoreClientProvider.overrideWithValue(core),
        keyValueStoreProvider.overrideWithValue(slow),
      ],
    );
    addTearDown(waiting.dispose);
    waiting.listen(talkSettingsControllerProvider, (_, _) {});

    await waiting
        .read(talkSettingsControllerProvider.notifier)
        .setMode(TalkMode.pushToTalk);
    loading.complete();
    await waiting.read(talkSettingsControllerProvider.future);

    expect(core.talkModes, isEmpty);
  });

  test('a change after disposal is not reported', () async {
    await loaded();
    final change = controller().setMode(TalkMode.pushToTalk);
    container.dispose();

    await change;

    expect(core.talkModes, [CoreTalkMode.pushToTalk]);
  });
}

/// Answers reads only once [_ready] completes.
final class _SlowStore implements KeyValueStore {
  new(this._ready);

  final Future<void> _ready;

  @override
  Future<String?> read(String key) async {
    await _ready;
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}
}
