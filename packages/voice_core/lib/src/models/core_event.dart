import 'package:equatable/equatable.dart';

/// Something the core reported (voice_core.h, vc_event_type).
sealed class CoreEvent extends Equatable {
  const new();
}

/// Lifecycle of the native session.
enum CoreState {
  /// The session is running.
  running,

  /// The session was stopped.
  stopped,

  /// vc_start failed; see [CoreStateChanged.errorCode].
  failed,
}

/// The session started, stopped or failed to start.
final class CoreStateChanged extends CoreEvent {
  /// Creates the event.
  const new(this.state, {this.errorCode});

  /// The new state.
  final CoreState state;

  /// The vc_result code, only for [CoreState.failed].
  final int? errorCode;

  @override
  List<Object?> get props => [state, errorCode];
}

/// The link to the peer came up or went down.
final class CoreLinkChanged extends CoreEvent {
  /// Creates the event.
  const new({required this.up, required this.peer});

  /// Whether the peer is reachable.
  final bool up;

  /// The peer endpoint, "a.b.c.d:port".
  final String peer;

  @override
  List<Object?> get props => [up, peer];
}

/// The local microphone started or stopped being sent (voice detector, push
/// to talk or mute).
final class CoreTalkingChanged extends CoreEvent {
  /// Creates the event.
  const new({required this.talking});

  /// Whether the microphone is being sent now.
  final bool talking;

  @override
  List<Object?> get props => [talking];
}
