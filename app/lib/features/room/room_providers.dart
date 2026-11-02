import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/features/room/data/repositories/room_repository_impl.dart';
import 'package:offtopic/features/room/data/services/permission_service_impl.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/room/domain/usecases/start_room.dart';
import 'package:offtopic/features/room/domain/usecases/stop_room.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_controller.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/presentation/controllers/stats_poller.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepositoryImpl(
    rooms: ref.watch(voicePlatformGatewayProvider),
    core: ref.watch(voiceCoreClientProvider),
  ),
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionServiceImpl(
    requester: ref.watch(permissionRequesterProvider),
    platformInfo: ref.watch(voicePlatformGatewayProvider),
  ),
);

final startRoomProvider = Provider<StartRoom>(
  (ref) => StartRoom(
    permissions: ref.watch(permissionServiceProvider),
    rooms: ref.watch(roomRepositoryProvider),
  ),
);

final stopRoomProvider = Provider<StopRoom>(
  (ref) => StopRoom(ref.watch(roomRepositoryProvider)),
);

final audioTestControllerProvider =
    NotifierProvider<AudioTestController, AudioTestState>(
      AudioTestController.new,
    );

/// Statistics at 4 Hz, only while a room is running.
final StreamProvider<SessionStats> sessionStatsProvider =
    StreamProvider.autoDispose<SessionStats>((ref) {
      final active = ref.watch(
        audioTestControllerProvider.select((state) => state is AudioTestActive),
      );
      if (!active) {
        return const Stream.empty();
      }
      return StatsPoller(read: ref.watch(roomRepositoryProvider).readStats)
          .watch();
    });

/// Link changes, while the room screen listens (the native callback is
/// registered only then).
final StreamProvider<RoomLink> roomLinkProvider =
    StreamProvider.autoDispose<RoomLink>(
      (ref) => ref.watch(roomRepositoryProvider).watchLink(),
    );
