import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_core/voice_core.dart';

import '../support/mock_voice_core_bindings.dart';

void main() {
  group('FfiVoiceCoreClient', () {
    late MockVoiceCoreBindings bindings;
    late NativeStrings strings;

    setUp(() {
      bindings = MockVoiceCoreBindings();
      strings = NativeStrings();
    });

    tearDown(() => strings.freeAll());

    test('decodes the UTF-8 version string returned by vc_version', () {
      when(bindings.vc_version).thenReturn(strings.allocate('0.1.0'));

      expect(FfiVoiceCoreClient(bindings).version, '0.1.0');
    });

    test('reads the version from the core on every access', () {
      when(bindings.vc_version).thenReturn(strings.allocate('0.1.0'));
      final client = FfiVoiceCoreClient(bindings)..version;

      when(bindings.vc_version).thenReturn(strings.allocate('0.2.0'));

      expect(client.version, '0.2.0');
      verify(bindings.vc_version).called(2);
    });

    test('throws a VoiceCoreException on a null pointer', () {
      when(bindings.vc_version).thenReturn(nullptr);

      expect(
        () => FfiVoiceCoreClient(bindings).version,
        throwsA(
          isA<VoiceCoreException>().having(
            (e) => e.message,
            'message',
            contains('vc_version'),
          ),
        ),
      );
    });

    test('open loads the library through the given loader', () {
      final openedFiles = <String>[];
      final loader = VoiceCoreLibraryLoader(
        operatingSystem: 'android',
        openLibrary: (fileName) {
          openedFiles.add(fileName);
          return DynamicLibrary.executable();
        },
      );

      final client = FfiVoiceCoreClient.open(loader: loader);

      expect(client, isA<FfiVoiceCoreClient>());
      expect(openedFiles, [VoiceCoreLibraryLoader.androidLibraryName]);
    });

    test('open uses the platform loader by default', () {
      // Tests run on a desktop host, where the core is not packaged.
      expect(FfiVoiceCoreClient.open, throwsUnsupportedError);
    });
  });
}
