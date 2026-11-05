/// How the microphone opens (vc_talk_mode).
enum CoreTalkMode {
  /// The voice detector opens it.
  voice,

  /// It opens only while the push-to-talk button is held.
  pushToTalk,
}

/// How easily the voice detector opens the microphone (vc_vad_sensitivity).
enum CoreVadSensitivity {
  /// Needs clear speech: fewer false openings in wind and engine noise.
  low,

  /// The default.
  medium,

  /// Also opens on quiet speech (and more noise).
  high,
}
