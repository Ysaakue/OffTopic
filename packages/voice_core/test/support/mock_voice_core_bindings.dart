import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';

class MockVoiceCoreBindings extends Mock implements VoiceCoreBindings;

/// Native strings allocated for a test, freed in [freeAll].
final class NativeStrings {
  final List<Pointer<Utf8>> _allocated = [];

  Pointer<Char> allocate(String value) {
    final pointer = value.toNativeUtf8();
    _allocated.add(pointer);
    return pointer.cast<Char>();
  }

  void freeAll() {
    _allocated
      ..forEach(malloc.free)
      ..clear();
  }
}
