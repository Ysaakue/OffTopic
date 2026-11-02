import 'package:equatable/equatable.dart';

/// The core's default session parameters (vc_config_defaults). They live in
/// the C++ CoreConfig only; Dart reads them instead of repeating them.
final class CoreDefaults extends Equatable {
  /// Creates a set of defaults.
  const new({
    required this.controlPort,
    required this.audioPort,
    required this.sampleRateHz,
    required this.frameSamples,
    required this.bitrateBps,
    required this.jitterMinMs,
    required this.jitterInitialMs,
    required this.jitterMaxMs,
    required this.keepaliveIntervalMs,
    required this.peerTimeoutMs,
  });

  /// TCP port of the control channel.
  final int controlPort;

  /// UDP port of the audio stream.
  final int audioPort;

  /// Audio sample rate.
  final int sampleRateHz;

  /// Samples per Opus frame.
  final int frameSamples;

  /// Opus bitrate.
  final int bitrateBps;

  /// Smallest jitter buffer target.
  final int jitterMinMs;

  /// Jitter buffer target before the network is measured.
  final int jitterInitialMs;

  /// Largest jitter buffer target.
  final int jitterMaxMs;

  /// Interval between keepalives.
  final int keepaliveIntervalMs;

  /// Silence after which the link is considered down.
  final int peerTimeoutMs;

  @override
  List<Object?> get props => [
    controlPort,
    audioPort,
    sampleRateHz,
    frameSamples,
    bitrateBps,
    jitterMinMs,
    jitterInitialMs,
    jitterMaxMs,
    keepaliveIntervalMs,
    peerTimeoutMs,
  ];
}
