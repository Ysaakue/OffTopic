/// Wi-Fi state as seen by the platform layer.
enum WifiState {
  /// Not known yet.
  unknown,

  /// No Wi-Fi network bound to the room.
  disconnected,

  /// Bound to the group's Wi-Fi network.
  connected,
}
