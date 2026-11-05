import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';

void main() {
  const stats = CoreStats(
    participants: 1,
    lossPct: 0,
    jitterMs: 0,
    jitterBufferMs: 40,
    jitterTargetMs: 40,
    rttMs: 30,
    inputLevel: 0,
    packetsSent: 0,
    packetsReceived: 0,
    packetsLost: 0,
    packetsLate: 0,
    fecRecovered: 0,
    concealedFrames: 0,
    playoutUnderruns: 0,
    captureOverruns: 0,
  );

  test('CoreStats compares every field', () {
    const other = CoreStats(
      participants: 1,
      lossPct: 0,
      jitterMs: 0,
      jitterBufferMs: 40,
      jitterTargetMs: 40,
      inputLevel: 0,
      packetsSent: 0,
      packetsReceived: 0,
      packetsLost: 0,
      packetsLate: 0,
      fecRecovered: 0,
      concealedFrames: 0,
      playoutUnderruns: 0,
      captureOverruns: 0,
    );

    expect(stats, isNot(other)); // only the RTT differs
    expect(stats.props, hasLength(16));
    expect(
      other,
      isNot(
        const CoreStats(
          participants: 1,
          lossPct: 0,
          jitterMs: 0,
          jitterBufferMs: 40,
          jitterTargetMs: 40,
          inputLevel: 0,
          packetsSent: 0,
          packetsReceived: 0,
          packetsLost: 0,
          packetsLate: 0,
          fecRecovered: 0,
          concealedFrames: 0,
          playoutUnderruns: 0,
          captureOverruns: 0,
          playoutQueueMs: 20,
        ),
      ),
    );
  });

  test('CoreDefaults compares every field', () {
    const changed = CoreDefaults(
      controlPort: 47800,
      audioPort: 47801,
      sampleRateHz: 16000,
      frameSamples: 320,
      bitrateBps: 24000,
      jitterMinMs: 20,
      jitterInitialMs: 40,
      jitterMaxMs: 120,
      keepaliveIntervalMs: 1000,
      peerTimeoutMs: 6000,
    );

    expect(sampleCoreDefaults, isNot(changed));
    expect(sampleCoreDefaults.props, hasLength(10));
  });
}
