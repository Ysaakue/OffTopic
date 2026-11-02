import 'package:equatable/equatable.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';

/// State of the phase 1 audio test screen.
sealed class AudioTestState extends Equatable {
  const new();

  @override
  List<Object?> get props => const [];
}

/// No room is running.
final class AudioTestIdle extends AudioTestState {
  const new();
}

/// Asking for permissions and starting the room.
final class AudioTestStarting extends AudioTestState {
  const new();
}

/// The room is running.
final class AudioTestActive extends AudioTestState {
  const new(this.request);

  /// What was started.
  final RoomRequest request;

  @override
  List<Object?> get props => [request];
}

/// Leaving the room.
final class AudioTestStopping extends AudioTestState {
  const new();
}

/// The room cannot start without a permission the rider refused.
final class AudioTestPermissionDenied extends AudioTestState {
  const new({required this.permanently});

  /// Only the app settings can grant it now.
  final bool permanently;

  @override
  List<Object?> get props => [permanently];
}

/// Starting or stopping failed.
final class AudioTestFailed extends AudioTestState {
  const new(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
