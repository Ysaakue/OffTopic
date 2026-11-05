import 'package:offtopic/features/room/domain/repositories/room_repository.dart';

/// The push-to-talk button: the microphone is sent while it is held.
final class PushToTalk {
  const new(this._rooms);

  final RoomRepository _rooms;

  void call({required bool pressed}) => _rooms.setPushToTalk(pressed: pressed);
}
