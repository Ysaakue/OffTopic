import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/di/infrastructure_providers.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/data/repositories/local_network_repository_impl.dart';
import 'package:offtopic/features/room/data/repositories/room_repository_impl.dart';
import 'package:offtopic/features/room/data/services/permission_service_impl.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/repositories/local_network_repository.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/room/domain/usecases/find_host_addresses.dart';
import 'package:offtopic/features/room/domain/usecases/push_to_talk.dart';
import 'package:offtopic/features/room/domain/usecases/start_room.dart';
import 'package:offtopic/features/room/domain/usecases/stop_room.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_controller.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/presentation/controllers/session_report_controller.dart';
import 'package:offtopic/features/room/presentation/controllers/stats_poller.dart';
import 'package:offtopic/features/settings/settings_providers.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepositoryImpl(
    rooms: ref.watch(voicePlatformGatewayProvider),
    platformState: ref.watch(voicePlatformGatewayProvider),
    core: ref.watch(voiceCoreClientProvider),
  ),
);

final localNetworkRepositoryProvider = Provider<LocalNetworkRepository>(
  (ref) => LocalNetworkRepositoryImpl(list: ref.watch(localInterfacesProvider)),
);

final findHostAddressesProvider = Provider<FindHostAddresses>(
  (ref) => FindHostAddresses(ref.watch(localNetworkRepositoryProvider)),
);

/// This phone's own addresses, for the host. Invalidate it to read them again.
final FutureProvider<Result<List<LocalAddress>>> hostAddressesProvider =
    FutureProvider.autoDispose<Result<List<LocalAddress>>>(
      (ref) => ref.watch(findHostAddressesProvider)(),
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
    settings: ref.watch(settingsRepositoryProvider),
  ),
);

final stopRoomProvider = Provider<StopRoom>(
  (ref) => StopRoom(ref.watch(roomRepositoryProvider)),
);

final pushToTalkProvider = Provider<PushToTalk>(
  (ref) => PushToTalk(ref.watch(roomRepositoryProvider)),
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

/// Whether the microphone is being sent, while the room screen listens.
final StreamProvider<bool> talkingProvider = StreamProvider.autoDispose<bool>(
  (ref) => ref.watch(roomRepositoryProvider).watchTalking(),
);

/// Where the room is heard and in which call mode, while the room screen
/// listens.
final StreamProvider<RoomAudio> roomAudioProvider =
    StreamProvider.autoDispose<RoomAudio>(
      (ref) => ref.watch(roomRepositoryProvider).watchAudio(),
    );

/// The report of the current (or last) room, built while the room screen is
/// in use.
final sessionReportControllerProvider =
    NotifierProvider<SessionReportController, SessionReport?>(
      SessionReportController.new,
    );
