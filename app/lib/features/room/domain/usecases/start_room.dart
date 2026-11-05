import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:offtopic/features/room/domain/repositories/room_repository.dart';
import 'package:offtopic/features/settings/domain/repositories/settings_repository.dart';

/// Asks for the room permissions, then starts the room with the rider's talk
/// settings. Without every permission the room never starts (Android 17
/// would silently block the local network).
final class StartRoom {
  const new({
    required this._permissions,
    required this._rooms,
    required this._settings,
  });

  final PermissionService _permissions;
  final RoomRepository _rooms;
  final SettingsRepository _settings;

  Future<Result<void>> call(RoomRequest request) async {
    final outcome = await _permissions.requestRoomPermissions();
    return switch (outcome) {
      PermissionOutcome.granted => await _rooms.start(
        request,
        talk: await _settings.loadTalkSettings(),
      ),
      PermissionOutcome.denied => const Failure(
        PermissionFailure(permanentlyDenied: false),
      ),
      PermissionOutcome.permanentlyDenied => const Failure(
        PermissionFailure(permanentlyDenied: true),
      ),
    };
  }
}
