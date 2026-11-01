import 'package:voice_core/src/voice_core_exception.dart';

/// Typed access to the native voice core.
abstract interface class VoiceCoreClient {
  /// Semantic version of the native core ("MAJOR.MINOR.PATCH").
  ///
  /// Throws a [VoiceCoreException] when the core cannot report it.
  String get version;
}
