import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/repositories/local_network_repository.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/room/domain/usecases/find_host_addresses.dart';
import 'package:offtopic/features/room/domain/usecases/push_to_talk.dart';
import 'package:offtopic/features/room/domain/usecases/start_room.dart';
import 'package:offtopic/features/room/domain/usecases/stop_room.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';

import '../../../../helpers/room_fixtures.dart';

class _MockPermissionService extends Mock implements PermissionService;

class _MockRoomRepository extends Mock implements RoomRepository;

class _MockSettingsRepository extends Mock implements SettingsRepository;

class _MockLocalNetworkRepository extends Mock
    implements LocalNetworkRepository;

void main() {
  late _MockPermissionService permissions;
  late _MockRoomRepository rooms;
  late _MockSettingsRepository settings;

  setUpAll(() {
    registerFallbackValue(hostRequest);
    registerFallbackValue(defaultTalk);
  });

  setUp(() {
    permissions = _MockPermissionService();
    rooms = _MockRoomRepository();
    settings = _MockSettingsRepository();
    when(() => rooms.start(any(), talk: any(named: 'talk')))
        .thenAnswer((_) async => const Success(null));
    when(rooms.stop).thenAnswer((_) async => const Success(null));
    when(settings.loadTalkSettings).thenAnswer((_) async => pushToTalkSettings);
  });

  group('StartRoom', () {
    StartRoom useCase() =>
        StartRoom(permissions: permissions, rooms: rooms, settings: settings);

    test('starts the room with the stored talk settings', () async {
      when(permissions.requestRoomPermissions)
          .thenAnswer((_) async => PermissionOutcome.granted);

      expect(await useCase()(joinRequest), const Success<void>(null));
      verify(() => rooms.start(joinRequest, talk: pushToTalkSettings))
          .called(1);
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
      verifyNever(() => rooms.start(any(), talk: any(named: 'talk')));
      verifyNever(settings.loadTalkSettings);
    });

    test('propagates a failed start', () async {
      const failure = RoomFailure(RoomFailureReason.network, 'no socket');
      when(permissions.requestRoomPermissions)
          .thenAnswer((_) async => PermissionOutcome.granted);
      when(() => rooms.start(any(), talk: any(named: 'talk')))
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

  group('PushToTalk', () {
    test('forwards the button', () {
      PushToTalk(rooms)
        ..call(pressed: true)
        ..call(pressed: false);

      verifyInOrder([
        () => rooms.setPushToTalk(pressed: true),
        () => rooms.setPushToTalk(pressed: false),
      ]);
    });
  });

  group('FindHostAddresses', () {
    test('returns the addresses of this phone', () async {
      final network = _MockLocalNetworkRepository();
      final addresses = Success<List<LocalAddress>>([hotspotAddress]);
      when(network.localAddresses).thenAnswer((_) async => addresses);

      expect(await FindHostAddresses(network)(), addresses);
    });
  });
}
