import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

/// The room session, owned by the platform service and the native core.
abstract interface class RoomRepository {
  /// Starts the room described by [request], with the microphone opening as
  /// [talk] says.
  Future<Result<void>> start(RoomRequest request, {required TalkSettings talk});

  /// Leaves the room. Succeeds when no room is running.
  Future<Result<void>> stop();

  /// Latest statistics, or null when no session is running.
  Result<SessionStats?> readStats();

  /// Applies [talk] to the running session (a new room starts from the
  /// settings it is given).
  Result<void> applyTalkSettings(TalkSettings talk);

  /// Push to talk: true while the button is held. The core cannot refuse it.
  void setPushToTalk({required bool pressed});

  /// Link changes reported by the core while someone listens.
  Stream<RoomLink> watchLink();

  /// Whether the microphone is being sent, on every change.
  Stream<bool> watchTalking();

  /// The room's audio (route and call mode), then every change.
  Stream<RoomAudio> watchAudio();

  /// Each time the native session stops, whoever stopped it: this app, or
  /// the phone ending the call (another call, the headset's hang-up button).
  Stream<void> watchSessionStopped();
}
