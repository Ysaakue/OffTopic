import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/src/voice_core_client.dart';
import 'package:voice_core/src/voice_core_exception.dart';
import 'package:voice_core/src/voice_core_library_loader.dart';

/// [VoiceCoreClient] backed by the C API of `libvoice_core`.
final class FfiVoiceCoreClient implements VoiceCoreClient {
  /// Wraps already loaded bindings; tests pass a mock here.
  new(this._bindings);

  /// Loads the native library for the current platform and wraps it.
  factory open({
    VoiceCoreLibraryLoader loader = const VoiceCoreLibraryLoader(),
  }) => FfiVoiceCoreClient(VoiceCoreBindings(loader.load()));

  final VoiceCoreBindings _bindings;

  @override
  String get version {
    final pointer = _bindings.vc_version();
    if (pointer == nullptr) {
      throw const VoiceCoreException('vc_version returned a null pointer.');
    }
    // The string is static inside the core: it must not be freed here.
    return pointer.cast<Utf8>().toDartString();
  }
}
