import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:voice_platform/voice_platform.dart';

/// Decides which permissions the room needs on this device and asks for them.
///
/// - Every platform: the microphone.
/// - Android 17+ (targetSdk 37): ACCESS_LOCAL_NETWORK, or the system blocks
///   every packet on the hotspot (docs/SPEC.md, addendum).
/// - Android 12+ (API 31): BLUETOOTH_CONNECT, to route the room to the
///   intercom. It shares the NEARBY_DEVICES group with ACCESS_LOCAL_NETWORK,
///   so Android 17 asks once for both.
final class PermissionServiceImpl implements PermissionService {
  const new({required this._requester, required this._platformInfo});

  /// First Android API level that needs ACCESS_LOCAL_NETWORK.
  static const localNetworkApiLevel = 37;

  /// First Android API level that needs BLUETOOTH_CONNECT.
  static const bluetoothConnectApiLevel = 31;

  static const _android = 'android';

  final PermissionRequester _requester;
  final PlatformInfoSource _platformInfo;

  @override
  Future<PermissionOutcome> requestRoomPermissions() async {
    final permissions = requiredPermissions(await _readPlatformInfo());
    final statuses = await _requester.request(permissions);
    final answers = [
      for (final permission in permissions)
        statuses[permission] ?? AppPermissionStatus.denied,
    ];
    if (answers.every((status) => status == AppPermissionStatus.granted)) {
      return PermissionOutcome.granted;
    }
    if (answers.contains(AppPermissionStatus.permanentlyDenied)) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }

  @override
  Future<void> openAppSettings() async {
    await _requester.openSettings();
  }

  /// The permissions a room needs on [platform] (null when unknown).
  static List<AppPermission> requiredPermissions(PlatformInfo? platform) {
    final androidApi = platform != null && platform.osName == _android
        ? platform.apiLevel
        : null;
    return [
      AppPermission.microphone,
      if (androidApi != null && androidApi >= bluetoothConnectApiLevel)
        AppPermission.bluetoothConnect,
      if (androidApi != null && androidApi >= localNetworkApiLevel)
        AppPermission.localNetwork,
    ];
  }

  Future<PlatformInfo?> _readPlatformInfo() async {
    try {
      return await _platformInfo.getPlatformInfo();
    } on VoicePlatformException {
      return null; // ask for what every platform needs
    }
  }
}
