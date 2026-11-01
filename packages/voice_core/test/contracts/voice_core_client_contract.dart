import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/voice_core.dart';

/// Arranges a [VoiceCoreClient] implementation for the contract suite.
abstract interface class VoiceCoreClientHarness {
  VoiceCoreClient get client;

  void arrangeVersion(String version);

  void arrangeVersionUnavailable();

  void dispose();
}

/// Behavior every [VoiceCoreClient] must share, so that the fake used by the
/// app tests can stand in for the FFI client (Liskov substitution).
void voiceCoreClientContract(
  String implementation,
  VoiceCoreClientHarness Function() createHarness,
) {
  group('$implementation honors the VoiceCoreClient contract:', () {
    late VoiceCoreClientHarness harness;

    setUp(() => harness = createHarness());
    tearDown(() => harness.dispose());

    test('reports the version the core exposes', () {
      harness.arrangeVersion('1.2.3');

      expect(harness.client.version, '1.2.3');
    });

    test('throws VoiceCoreException when the version is unavailable', () {
      harness.arrangeVersionUnavailable();

      expect(() => harness.client.version, throwsA(isA<VoiceCoreException>()));
    });
  });
}
