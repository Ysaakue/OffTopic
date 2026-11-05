import 'package:voice_core/src/models/core_defaults.dart';
import 'package:voice_core/src/models/core_event.dart';
import 'package:voice_core/src/models/core_stats.dart';
import 'package:voice_core/src/models/voice_controls.dart';
import 'package:voice_core/src/voice_core_exception.dart';

/// What the core is: its version and its default parameters.
abstract interface class VoiceCoreInfo {
  /// Semantic version of the native core ("MAJOR.MINOR.PATCH").
  ///
  /// Throws a [VoiceCoreException] when the core cannot report it.
  String get version;

  /// The core's default session parameters.
  CoreDefaults get defaults;
}

/// Polled statistics of the running session (the UI reads them at 4 Hz).
abstract interface class VoiceCoreStats {
  /// The latest statistics, or null when no session is running.
  ///
  /// Throws a [VoiceCoreException] on any other failure.
  CoreStats? readStats();
}

/// Events pushed by the core.
abstract interface class VoiceCoreEvents {
  /// Broadcast stream of core events. The native callback is registered while
  /// the stream has listeners. Payloads that cannot be decoded arrive as
  /// [VoiceCoreException] errors.
  Stream<CoreEvent> get events;
}

/// Fine-grained controls Dart sends directly (the lifecycle and mute go
/// through the platform layer).
abstract interface class VoiceCoreControls {
  /// Playback gain; the core clamps it to [0, 4].
  void setOutputGain(double gain);

  /// Switches between the voice detector and push to talk while the session
  /// runs (a new session starts from its configuration).
  void setTalkMode(CoreTalkMode mode);

  /// Push to talk: true while the button is held.
  void setPushToTalk({required bool pressed});

  /// How easily the voice detector opens the microphone.
  void setVadSensitivity(CoreVadSensitivity sensitivity);
}

/// Typed access to the native voice core.
abstract interface class VoiceCoreClient
    implements
        VoiceCoreInfo,
        VoiceCoreStats,
        VoiceCoreEvents,
        VoiceCoreControls {
  /// Unregisters the event callback and closes [events].
  void dispose();
}
