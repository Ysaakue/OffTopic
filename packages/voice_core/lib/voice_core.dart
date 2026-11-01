/// Dart client for the OffTopic native voice core (C++ through dart:ffi).
///
/// No audio samples ever cross into Dart: this library only reads state and
/// sends commands to the core.
library;

export 'src/ffi_voice_core_client.dart' show FfiVoiceCoreClient;
export 'src/voice_core_client.dart';
export 'src/voice_core_exception.dart';
export 'src/voice_core_library_loader.dart';
