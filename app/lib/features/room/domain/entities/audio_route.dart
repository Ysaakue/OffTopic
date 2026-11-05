/// Where the room is heard and spoken into.
enum AudioRoute {
  /// No route yet (no room running) or one the platform cannot name.
  unknown,

  /// The rider's Bluetooth intercom (hands-free profile).
  intercom,

  /// A wired or USB headset.
  headset,

  /// The phone's loudspeaker.
  speaker,

  /// The phone's earpiece.
  earpiece,
}
