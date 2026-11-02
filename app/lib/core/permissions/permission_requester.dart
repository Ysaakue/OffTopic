/// Runtime permissions the app asks for.
enum AppPermission {
  /// RECORD_AUDIO on Android.
  microphone,

  /// ACCESS_LOCAL_NETWORK on Android 17 (API 37) and later.
  localNetwork,
}

/// What the system answered for one permission.
enum AppPermissionStatus {
  /// Granted (fully or partially).
  granted,

  /// Refused this time.
  denied,

  /// Refused for good, or blocked by policy.
  permanentlyDenied,
}

/// Asks the operating system for permissions. Wraps the permission plugin so
/// that the rules about which permissions to ask stay plain, testable Dart.
abstract interface class PermissionRequester {
  /// Asks for [permissions] and returns the status of each one.
  Future<Map<AppPermission, AppPermissionStatus>> request(
    List<AppPermission> permissions,
  );

  /// Opens the app's page in the system settings.
  Future<bool> openSettings();
}
