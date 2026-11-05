/// Dart client for the OffTopic native voice core (C++ through dart:ffi).
///
/// No audio samples ever cross into Dart: this library only reads state and
/// sends commands to the core.
library;

export 'src/event_decoder.dart';
export 'src/ffi_voice_core_client.dart' show FfiVoiceCoreClient;
export 'src/models/core_defaults.dart';
export 'src/models/core_event.dart';
export 'src/models/core_stats.dart';
export 'src/models/voice_controls.dart';
export 'src/voice_core_client.dart';
export 'src/voice_core_exception.dart';
export 'src/voice_core_library_loader.dart';
