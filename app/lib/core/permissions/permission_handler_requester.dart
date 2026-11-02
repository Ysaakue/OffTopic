import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:permission_handler/permission_handler.dart';

/// [PermissionRequester] on top of the permission_handler plugin.
final class PermissionHandlerRequester implements PermissionRequester {
  const new();

  @override
  Future<Map<AppPermission, AppPermissionStatus>> request(
    List<AppPermission> permissions,
  ) async {
    final statuses = await [for (final p in permissions) _toPlugin(p)]
        .request();
    return {
      for (final permission in permissions)
        permission: _fromPlugin(
          statuses[_toPlugin(permission)] ?? PermissionStatus.denied,
        ),
    };
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  static Permission _toPlugin(AppPermission permission) => switch (permission) {
    AppPermission.microphone => Permission.microphone,
    AppPermission.localNetwork => Permission.accessLocalNetwork,
  };

  static AppPermissionStatus _fromPlugin(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.limited ||
        PermissionStatus.provisional => AppPermissionStatus.granted,
        PermissionStatus.denied => AppPermissionStatus.denied,
        PermissionStatus.permanentlyDenied ||
        PermissionStatus.restricted => AppPermissionStatus.permanentlyDenied,
      };
}
