/// Result of asking for the room permissions.
enum PermissionOutcome {
  /// Everything the room needs was granted.
  granted,

  /// Refused this time; the system may ask again.
  denied,

  /// Refused for good; only the app settings can grant it.
  permanentlyDenied,
}

/// The runtime permissions a room needs. Each platform (and each Android
/// version) needs a different set, so this is a domain contract.
abstract interface class PermissionService {
  /// Asks for every permission the room needs on this device.
  Future<PermissionOutcome> requestRoomPermissions();

  /// Opens the system settings of the app.
  Future<void> openAppSettings();
}
