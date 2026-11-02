import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';

/// Leaves the room.
final class StopRoom {
  const new(this._rooms);

  final RoomRepository _rooms;

  Future<Result<void>> call() => _rooms.stop();
}
