import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/room/domain/usecases/start_room.dart';
import 'package:offtopic/features/room/domain/usecases/stop_room.dart';

import '../../../../helpers/room_fixtures.dart';

class _MockPermissionService extends Mock implements PermissionService;

class _MockRoomRepository extends Mock implements RoomRepository;

void main() {
  late _MockPermissionService permissions;
  late _MockRoomRepository rooms;

  setUpAll(() => registerFallbackValue(hostRequest));

  setUp(() {
    permissions = _MockPermissionService();
    rooms = _MockRoomRepository();
    when(() => rooms.start(any())).thenAnswer((_) async => const Success(null));
    when(rooms.stop).thenAnswer((_) async => const Success(null));
  });

  group('StartRoom', () {
    StartRoom useCase() => StartRoom(permissions: permissions, rooms: rooms);

    test('starts the room once every permission is granted', () async {
      when(permissions.requestRoomPermissions)
          .thenAnswer((_) async => PermissionOutcome.granted);

      expect(await useCase()(joinRequest), const Success<void>(null));
      verify(() => rooms.start(joinRequest)).called(1);
    });

    test('never starts without the permissions', () async {
      for (final (outcome, permanently) in [
        (PermissionOutcome.denied, false),
        (PermissionOutcome.permanentlyDenied, true),
      ]) {
        when(permissions.requestRoomPermissions)
            .thenAnswer((_) async => outcome);

        expect(
          await useCase()(joinRequest),
          Failure<void>(PermissionFailure(permanentlyDenied: permanently)),
        );
      }
      verifyNever(() => rooms.start(any()));
    });

    test('propagates a failed start', () async {
      const failure = RoomFailure(RoomFailureReason.network, 'no socket');
      when(permissions.requestRoomPermissions)
          .thenAnswer((_) async => PermissionOutcome.granted);
      when(() => rooms.start(any()))
          .thenAnswer((_) async => const Failure(failure));

      expect(await useCase()(hostRequest), const Failure<void>(failure));
    });
  });

  group('StopRoom', () {
    test('stops the room', () async {
      expect(await StopRoom(rooms)(), const Success<void>(null));
      verify(rooms.stop).called(1);
    });
  });
}
