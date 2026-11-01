/// Role of this phone in the room.
enum RoomRole {
  /// Mixes everyone's voice (mix-minus) and runs the hotspot.
  host,

  /// Sends its voice to the host and plays the mix it receives.
  client,
}
