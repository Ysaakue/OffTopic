/// How easily the voice detector opens the microphone.
enum VadSensitivity {
  /// Needs clear speech: fewer false openings in wind and engine noise.
  low,

  /// The default.
  medium,

  /// Also opens on quiet speech (and more noise).
  high,
}
