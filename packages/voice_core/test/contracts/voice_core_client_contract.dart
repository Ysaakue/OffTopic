import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/voice_core.dart';

/// Arranges a [VoiceCoreClient] implementation for the contract suite.
abstract interface class VoiceCoreClientHarness {
  VoiceCoreClient get client;

  void arrangeVersion(String version);

  void arrangeVersionUnavailable();

  void arrangeDefaults(CoreDefaults defaults);

  /// No session is running.
  void arrangeIdle();

  void arrangeStats(CoreStats stats);

  void arrangeStatsFailure();

  /// Makes the core report [event] (through its native callback for FFI).
  void deliver(CoreEvent event);

  /// Makes the core report a payload that cannot be decoded.
  void deliverInvalid();

  /// Whether the core currently has an event callback registered.
  bool get eventsRegistered;

  /// The last gain the core received.
  double? get lastOutputGain;

  void dispose();
}

const _stats = CoreStats(
  participants: 1,
  lossPct: 2.5,
  jitterMs: 4.5,
  jitterBufferMs: 60,
  jitterTargetMs: 40,
  rttMs: 35,
  inputLevel: 0.5,
  packetsSent: 10,
  packetsReceived: 9,
  packetsLost: 1,
  packetsLate: 2,
  fecRecovered: 3,
  concealedFrames: 4,
  playoutUnderruns: 5,
  captureOverruns: 6,
);

const _defaults = CoreDefaults(
  controlPort: 1,
  audioPort: 2,
  sampleRateHz: 16000,
  frameSamples: 320,
  bitrateBps: 3,
  jitterMinMs: 4,
  jitterInitialMs: 5,
  jitterMaxMs: 6,
  keepaliveIntervalMs: 7,
  peerTimeoutMs: 8,
);

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

    test('reports the core defaults', () {
      harness.arrangeDefaults(_defaults);

      expect(harness.client.defaults, _defaults);
    });

    test('has no statistics while no session runs', () {
      harness.arrangeIdle();

      expect(harness.client.readStats(), isNull);
    });

    test('reads the statistics of a running session', () {
      harness.arrangeStats(_stats);

      expect(harness.client.readStats(), _stats);
    });

    test('throws VoiceCoreException when statistics fail', () {
      harness.arrangeStatsFailure();

      expect(harness.client.readStats, throwsA(isA<VoiceCoreException>()));
    });

    test('forwards the output gain', () {
      harness.client.setOutputGain(0.75);

      expect(harness.lastOutputGain, 0.75);
    });

    test('delivers events in order while someone listens', () async {
      expect(harness.eventsRegistered, isFalse);
      final events = <CoreEvent>[];
      final subscription = harness.client.events.listen(events.add);
      expect(harness.eventsRegistered, isTrue);

      harness
        ..deliver(const CoreStateChanged(CoreState.running))
        ..deliver(const CoreLinkChanged(up: true, peer: '192.168.43.1:47801'));
      await pumpEventQueue();

      expect(events, const [
        CoreStateChanged(CoreState.running),
        CoreLinkChanged(up: true, peer: '192.168.43.1:47801'),
      ]);
      await subscription.cancel();
      expect(harness.eventsRegistered, isFalse);
    });

    test('reports undecodable events as errors', () async {
      final errors = <Object>[];
      final subscription = harness.client.events.listen(
        (_) {},
        onError: errors.add,
      );

      harness.deliverInvalid();
      await pumpEventQueue();

      expect(errors.single, isA<VoiceCoreException>());
      await subscription.cancel();
    });

    test('closes the event stream on dispose', () async {
      final done = harness.client.events.toList();

      harness.client.dispose();

      expect(await done, isEmpty);
    });
  });
}
