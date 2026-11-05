import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/room_providers.dart';
import 'package:offtopic/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';
import 'package:offtopic/features/settings/domain/usecases/update_talk_settings.dart';
import 'package:offtopic/features/settings/presentation/controllers/talk_settings_controller.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(keyValueStoreProvider)),
);

final updateTalkSettingsProvider = Provider<UpdateTalkSettings>(
  (ref) => UpdateTalkSettings(
    settings: ref.watch(settingsRepositoryProvider),
    rooms: ref.watch(roomRepositoryProvider),
  ),
);

final talkSettingsControllerProvider =
    AsyncNotifierProvider<TalkSettingsController, TalkSettingsState>(
      TalkSettingsController.new,
    );
