import 'package:equatable/equatable.dart';
import 'package:voice_platform/src/models/room_role.dart';
import 'package:voice_platform/src/models/talk_mode.dart';
import 'package:voice_platform/src/models/vad_sensitivity.dart';

/// Parameters the platform service needs to start a room.
final class RoomConfig extends Equatable {
  /// Creates a room configuration.
  const new({
    required this.role,
    required this.displayName,
    required this.controlPort,
    required this.audioPort,
    required this.bitrateBps,
    this.hostIp,
    this.echoMode = false,
    this.talkMode = TalkMode.voice,
    this.vadSensitivity = VadSensitivity.medium,
  });

  /// Whether this phone hosts or joins the room.
  final RoomRole role;

  /// IPv4 address of the host; null when this phone is the host.
  final String? hostIp;

  /// Name shown to the other riders.
  final String displayName;

  /// TCP port of the control channel.
  final int controlPort;

  /// UDP port of the audio stream.
  final int audioPort;

  /// Opus bitrate in bits per second.
  final int bitrateBps;

  /// Host only: return every audio packet to its sender, to measure the
  /// audio round trip.
  final bool echoMode;

  /// How the microphone opens when the room starts.
  final TalkMode talkMode;

  /// The voice detector's sensitivity when the room starts.
  final VadSensitivity vadSensitivity;

  @override
  List<Object?> get props => [
    role,
    hostIp,
    displayName,
    controlPort,
    audioPort,
    bitrateBps,
    echoMode,
    talkMode,
    vadSensitivity,
  ];
}
