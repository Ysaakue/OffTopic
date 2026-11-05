import 'package:equatable/equatable.dart';

/// Snapshot of the running session (vc_get_stats).
final class CoreStats extends Equatable {
  /// Creates a snapshot.
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
    required this.captureOverruns,
    this.playoutQueueMs = 0,
    this.rttMs,
  });

  /// Peers with a live link.
  final int participants;

  /// Network loss over the last statistics window, in percent.
  final double lossPct;

  /// RFC 3550 interarrival jitter.
  final double jitterMs;

  /// Audio currently buffered against jitter.
  final int jitterBufferMs;

  /// Delay the adaptive buffer aims for.
  final int jitterTargetMs;

  /// Keepalive round trip; null until measured.
  final int? rttMs;

  /// Peak of the last captured frame, 0..1.
  final double inputLevel;

  /// Audio packets sent.
  final int packetsSent;

  /// Audio packets received.
  final int packetsReceived;

  /// Packets that never arrived (sequence gaps).
  final int packetsLost;

  /// Packets that arrived after their playout time.
  final int packetsLate;

  /// Lost frames rebuilt from the next packet's FEC.
  final int fecRecovered;

  /// Frames synthesized by packet loss concealment.
  final int concealedFrames;

  /// Times the speaker ran out of audio.
  final int playoutUnderruns;

  /// Times captured audio was dropped.
  final int captureOverruns;

  /// Decoded audio waiting for the speaker, in milliseconds.
  final int playoutQueueMs;

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
    captureOverruns,
    playoutQueueMs,
  ];
}
