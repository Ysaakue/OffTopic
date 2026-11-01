import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';

void main() {
  group('FakeVoiceCoreClient', () {
    test('defaults to version 0.0.0', () {
      expect(FakeVoiceCoreClient().version, '0.0.0');
    });

    test('reports the configured version', () {
      final fake = FakeVoiceCoreClient(version: '0.1.0');

      expect(fake.version, '0.1.0');
    });

    test('throws the configured error until it is cleared', () {
      const error = VoiceCoreException('boom');
      final fake = FakeVoiceCoreClient(versionError: error);

      expect(() => fake.version, throwsA(same(error)));

      fake.versionError = null;
      expect(fake.version, '0.0.0');
    });
  });
}
