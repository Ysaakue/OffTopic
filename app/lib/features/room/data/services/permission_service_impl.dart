import 'package:offtopic/core/permissions/permission_requester.dart';
import 'package:offtopic/features/room/domain/repositories/permission_service.dart';
import 'package:voice_platform/voice_platform.dart';

/// Decides which permissions the room needs on this device and asks for them.
///
/// - Every platform: the microphone.
/// - Android 17+ (targetSdk 37): ACCESS_LOCAL_NETWORK, or the system blocks
///   every packet on the hotspot (docs/SPEC.md, addendum).
/// - Phase 2 adds BLUETOOTH_CONNECT (API 31+), same NEARBY_DEVICES group.
final class PermissionServiceImpl implements PermissionService {
  const new({required this._requester, required this._platformInfo});

  /// First Android API level that needs ACCESS_LOCAL_NETWORK.
  static const localNetworkApiLevel = 37;

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
  static List<AppPermission> requiredPermissions(PlatformInfo? platform) => [
    AppPermission.microphone,
    if (platform != null &&
        platform.osName == _android &&
        platform.apiLevel >= localNetworkApiLevel)
      AppPermission.localNetwork,
  ];

  Future<PlatformInfo?> _readPlatformInfo() async {
    try {
      return await _platformInfo.getPlatformInfo();
    } on VoicePlatformException {
      return null; // ask for what every platform needs
    }
  }
}
