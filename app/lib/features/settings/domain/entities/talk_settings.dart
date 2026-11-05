import 'package:equatable/equatable.dart';

/// How the microphone opens.
enum TalkMode {
  /// The voice detector opens it when the rider speaks.
  voice,

  /// It opens only while the push-to-talk button is held.
  pushToTalk,
}

/// How easily the voice detector opens the microphone.
enum VadSensitivity {
  /// Needs clear speech: fewer false openings in wind and engine noise.
  low,

  /// The default.
  medium,

  /// Also opens on quiet speech (and more noise).
  high,
}

/// The rider's talk preferences, kept between rooms.
final class TalkSettings extends Equatable {
  const new({
    this.mode = TalkMode.voice,
    this.sensitivity = VadSensitivity.medium,
  });

  final TalkMode mode;
  final VadSensitivity sensitivity;

  TalkSettings copyWith({TalkMode? mode, VadSensitivity? sensitivity}) =>
      TalkSettings(
        mode: mode ?? this.mode,
        sensitivity: sensitivity ?? this.sensitivity,
      );

  @override
  List<Object?> get props => [mode, sensitivity];
}
