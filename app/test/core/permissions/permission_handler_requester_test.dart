import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/permissions/permission_handler_requester.dart';
import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Replaces the plugin's platform implementation (the federated plugin
/// pattern), so the real PermissionHandlerRequester runs without a device.
final class _FakePermissionPlatform extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  Map<Permission, PermissionStatus> answers = {};
  List<Permission> requested = [];
  int settingsOpened = 0;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requested = permissions;
    return {
      for (final permission in permissions) permission: ?answers[permission],
    };
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  late _FakePermissionPlatform platform;
  const requester = PermissionHandlerRequester();

  setUp(() {
    platform = _FakePermissionPlatform();
    PermissionHandlerPlatform.instance = platform;
  });

  test('asks the plugin for the matching permissions', () async {
    await requester.request(AppPermission.values);

    expect(platform.requested, [
      Permission.microphone,
      Permission.accessLocalNetwork,
    ]);
  });

  test('maps every plugin status', () async {
    for (final (status, expected) in [
      (PermissionStatus.granted, AppPermissionStatus.granted),
      (PermissionStatus.limited, AppPermissionStatus.granted),
      (PermissionStatus.provisional, AppPermissionStatus.granted),
      (PermissionStatus.denied, AppPermissionStatus.denied),
      (
        PermissionStatus.permanentlyDenied,
        AppPermissionStatus.permanentlyDenied,
      ),
      (PermissionStatus.restricted, AppPermissionStatus.permanentlyDenied),
    ]) {
      platform.answers = {Permission.microphone: status};

      expect(await requester.request([AppPermission.microphone]), {
        AppPermission.microphone: expected,
      }, reason: '$status');
    }
  });

  test('treats a missing answer as denied', () async {
    expect(await requester.request([AppPermission.localNetwork]), {
      AppPermission.localNetwork: AppPermissionStatus.denied,
    });
  });

  test('opens the app settings', () async {
    expect(await requester.openSettings(), isTrue);
    expect(platform.settingsOpened, 1);
  });
}
