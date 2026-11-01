import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/voice_core.dart';

void main() {
  group('VoiceCoreLibraryLoader', () {
    final hostLibrary = DynamicLibrary.executable();

    test('opens libvoice_core.so on Android', () {
      String? opened;
      final loader = VoiceCoreLibraryLoader(
        operatingSystem: 'android',
        openLibrary: (fileName) {
          opened = fileName;
          return hostLibrary;
        },
        processLibrary: () => fail('Android must not use the process library'),
      );

      expect(loader.load(), same(hostLibrary));
      expect(opened, 'libvoice_core.so');
    });

    test('uses the process library on iOS, where the core is linked in', () {
      var processCalls = 0;
      final loader = VoiceCoreLibraryLoader(
        operatingSystem: 'ios',
        openLibrary: (_) => fail('iOS must not open a file'),
        processLibrary: () {
          processCalls++;
          return hostLibrary;
        },
      );

      expect(loader.load(), same(hostLibrary));
      expect(processCalls, 1);
    });

    test('rejects platforms without a packaged core', () {
      const loader = VoiceCoreLibraryLoader(operatingSystem: 'windows');

      expect(
        loader.load,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('windows'),
          ),
        ),
      );
    });

    test('defaults to the running operating system', () {
      String? opened;
      final loader = VoiceCoreLibraryLoader(
        openLibrary: (fileName) {
          opened = fileName;
          return hostLibrary;
        },
        processLibrary: () => hostLibrary,
      );

      if (Platform.isAndroid || Platform.isIOS) {
        expect(loader.load(), same(hostLibrary));
      } else {
        expect(loader.load, throwsUnsupportedError);
        expect(opened, isNull);
      }
    });
  });
}
