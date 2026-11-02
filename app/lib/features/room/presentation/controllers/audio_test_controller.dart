import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/presentation/controllers/audio_test_state.dart';
import 'package:offtopic/features/room/room_providers.dart';

/// Drives the phase 1 audio test: idle -> starting -> active -> stopping,
/// with the permission and failure paths.
final class AudioTestController extends Notifier<AudioTestState> {
  @override
  AudioTestState build() => const AudioTestIdle();

  /// Starts a room; ignored while one is starting, running or stopping.
  Future<void> start(RoomRequest request) async {
    if (_busy) {
      return;
    }
    state = const AudioTestStarting();
    final result = await ref.read(startRoomProvider).call(request);
    if (!ref.mounted) {
      return;
    }
    state = switch (result) {
      Success() => AudioTestActive(request),
      Failure(failure: PermissionFailure(:final permanentlyDenied)) =>
        AudioTestPermissionDenied(permanently: permanentlyDenied),
      Failure(:final failure) => AudioTestFailed(failure),
    };
  }

  /// Leaves the running room.
  Future<void> stop() async {
    if (state is! AudioTestActive) {
      return;
    }
    state = const AudioTestStopping();
    final result = await ref.read(stopRoomProvider).call();
    if (!ref.mounted) {
      return;
    }
    state = switch (result) {
      Success() => const AudioTestIdle(),
      Failure(:final failure) => AudioTestFailed(failure),
    };
  }

  /// Opens the app settings, where a refused permission can be granted.
  Future<void> openSettings() =>
      ref.read(permissionServiceProvider).openAppSettings();

  /// Back to the form after a failure or a refused permission.
  void dismiss() {
    if (state is AudioTestFailed || state is AudioTestPermissionDenied) {
      state = const AudioTestIdle();
    }
  }

  bool get _busy =>
      state is AudioTestStarting ||
      state is AudioTestActive ||
      state is AudioTestStopping;
}
