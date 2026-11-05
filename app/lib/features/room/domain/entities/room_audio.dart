import 'package:equatable/equatable.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';

/// Where the room is heard, and how the phone got there.
final class RoomAudio extends Equatable {
  const new({this.route = AudioRoute.unknown, this.systemCall = false});

  final AudioRoute route;

  /// The room is a call registered with the phone (as WhatsApp does), so the
  /// intercom sees a real call and runs its own noise suppression. False
  /// when the phone could only route the audio.
  final bool systemCall;

  @override
  List<Object?> get props => [route, systemCall];
}
