import 'package:offtopic/core/permissions/permission_requester.dart';

/// Answers every permission request with [statuses] (granted by default) and
/// records what was asked.
final class FakePermissionRequester implements PermissionRequester {
  Map<AppPermission, AppPermissionStatus> statuses = {
    for (final permission in AppPermission.values)
      permission: AppPermissionStatus.granted,
  };

  final List<List<AppPermission>> requests = [];
  int settingsOpened = 0;

  @override
  Future<Map<AppPermission, AppPermissionStatus>> request(
    List<AppPermission> permissions,
  ) async {
    requests.add(permissions);
    return {
      for (final permission in permissions) permission: ?statuses[permission],
    };
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
