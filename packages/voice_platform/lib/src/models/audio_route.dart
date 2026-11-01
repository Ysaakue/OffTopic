/// Where the room audio is currently routed.
enum AudioRoute {
  /// Not known yet (no room running).
  unknown,

  /// Bluetooth headset in HFP mode (the rider's intercom).
  bluetoothHeadset,

  /// Wired headset.
  wiredHeadset,

  /// Phone loudspeaker.
  speaker,

  /// Phone earpiece.
  earpiece,
}
