import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';

/// The room session, owned by the platform service and the native core.
abstract interface class RoomRepository {
  /// Starts the room described by [request].
  Future<Result<void>> start(RoomRequest request);

  /// Leaves the room. Succeeds when no room is running.
  Future<Result<void>> stop();

  /// Latest statistics, or null when no session is running.
  Result<SessionStats?> readStats();

  /// Link changes reported by the core while someone listens.
  Stream<RoomLink> watchLink();
}
