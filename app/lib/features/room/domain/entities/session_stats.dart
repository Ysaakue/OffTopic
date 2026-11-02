import 'package:equatable/equatable.dart';

/// Health of the running session, polled at 4 Hz for the diagnostics.
final class SessionStats extends Equatable {
  const new({
    required this.participants,
    required this.lossPct,
    required this.jitterMs,
    required this.jitterBufferMs,
    required this.jitterTargetMs,
    required this.inputLevel,
    required this.packetsSent,
    required this.packetsReceived,
    required this.packetsLost,
    required this.packetsLate,
    required this.fecRecovered,
    required this.concealedFrames,
    required this.playoutUnderruns,
    this.rttMs,
  });

  /// Peers with a live link.
  final int participants;

  /// Network loss over the last second, in percent.
  final double lossPct;

  /// Interarrival jitter (RFC 3550).
  final double jitterMs;

  /// Audio buffered against jitter.
  final int jitterBufferMs;

  /// Delay the adaptive buffer aims for.
  final int jitterTargetMs;

  /// Keepalive round trip; null until measured.
  final int? rttMs;

  /// Microphone peak, 0..1.
  final double inputLevel;

  final int packetsSent;
  final int packetsReceived;
  final int packetsLost;
  final int packetsLate;
  final int fecRecovered;
  final int concealedFrames;

  /// Times the speaker ran out of audio.
  final int playoutUnderruns;

  /// Whether the other phone is reachable.
  bool get linkUp => participants > 0;

  @override
  List<Object?> get props => [
    participants,
    lossPct,
    jitterMs,
    jitterBufferMs,
    jitterTargetMs,
    rttMs,
    inputLevel,
    packetsSent,
    packetsReceived,
    packetsLost,
    packetsLate,
    fecRecovered,
    concealedFrames,
    playoutUnderruns,
  ];
}
