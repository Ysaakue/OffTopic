import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';
import 'package:offtopic/features/settings/domain/usecases/update_talk_settings.dart';

import '../../../../helpers/room_fixtures.dart';

class _MockRoomRepository extends Mock implements RoomRepository;

class _MockSettingsRepository extends Mock implements SettingsRepository;

void main() {
  late _MockRoomRepository rooms;
  late _MockSettingsRepository settings;
  late UpdateTalkSettings update;

  setUpAll(() => registerFallbackValue(defaultTalk));

  setUp(() {
    rooms = _MockRoomRepository();
    settings = _MockSettingsRepository();
    update = UpdateTalkSettings(settings: settings, rooms: rooms);
    when(() => rooms.applyTalkSettings(any())).thenReturn(const Success(null));
    when(() => settings.saveTalkSettings(any()))
        .thenAnswer((_) async => const Success(null));
  });

  test('applies the settings to the room, then stores them', () async {
    expect(await update(pushToTalkSettings), const Success<void>(null));

    verifyInOrder([
      () => rooms.applyTalkSettings(pushToTalkSettings),
      () => settings.saveTalkSettings(pushToTalkSettings),
    ]);
  });

  test('reports a refused live change but still stores it', () async {
    const failure = CoreFailure('refused');
    when(() => rooms.applyTalkSettings(any()))
        .thenReturn(const Failure(failure));

    expect(await update(pushToTalkSettings), const Failure<void>(failure));
    verify(() => settings.saveTalkSettings(pushToTalkSettings)).called(1);
  });

  test('reports a storage failure', () async {
    const failure = StorageFailure('disk full');
    when(() => settings.saveTalkSettings(any()))
        .thenAnswer((_) async => const Failure(failure));

    expect(await update(pushToTalkSettings), const Failure<void>(failure));
  });
}
