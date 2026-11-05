import 'dart:async';

import 'package:voice_core/src/models/core_defaults.dart';
import 'package:voice_core/src/models/core_event.dart';
import 'package:voice_core/src/models/core_stats.dart';
import 'package:voice_core/src/models/voice_controls.dart';
import 'package:voice_core/src/voice_core_client.dart';
import 'package:voice_core/src/voice_core_exception.dart';

/// Defaults matching the core's CoreConfig, for tests.
const sampleCoreDefaults = CoreDefaults(
  controlPort: 47800,
  audioPort: 47801,
  sampleRateHz: 16000,
  frameSamples: 320,
  bitrateBps: 24000,
  jitterMinMs: 20,
  jitterInitialMs: 40,
  jitterMaxMs: 120,
  keepaliveIntervalMs: 1000,
  peerTimeoutMs: 5000,
);

/// In-memory [VoiceCoreClient] for tests.
///
/// It honors the same contract as the FFI client (see
/// test/contracts/voice_core_client_contract.dart in this package).
final class FakeVoiceCoreClient implements VoiceCoreClient {
  /// Creates a fake reporting [_version], or throwing [versionError] if set.
  new({
    this._version = '0.0.0',
    this.versionError,
    this.defaults = sampleCoreDefaults,
    this.stats,
  });

  String _version;

  /// When set, reading [version] throws it.
  VoiceCoreException? versionError;

  @override
  CoreDefaults defaults;

  /// What [readStats] returns; null means no session is running.
  CoreStats? stats;

  /// When set, [readStats] throws it.
  VoiceCoreException? statsError;

  /// How many times [readStats] was called.
  int statsReads = 0;

  /// Every gain passed to [setOutputGain].
  final List<double> outputGains = [];

  /// Every mode passed to [setTalkMode].
  final List<CoreTalkMode> talkModes = [];

  /// Every state passed to [setPushToTalk].
  final List<bool> pushToTalk = [];

  /// Every sensitivity passed to [setVadSensitivity].
  final List<CoreVadSensitivity> vadSensitivities = [];

  /// Whether [dispose] was called.
  bool disposed = false;

  final StreamController<CoreEvent> _events = StreamController.broadcast();

  @override
  String get version {
    final error = versionError;
    if (error != null) {
      throw error;
    }
    return _version;
  }

  set version(String value) => _version = value;

  @override
  CoreStats? readStats() {
    statsReads++;
    final error = statsError;
    if (error != null) {
      throw error;
    }
    return stats;
  }

  @override
  void setOutputGain(double gain) => outputGains.add(gain);

  @override
  void setTalkMode(CoreTalkMode mode) => talkModes.add(mode);

  @override
  void setPushToTalk({required bool pressed}) => pushToTalk.add(pressed);

  @override
  void setVadSensitivity(CoreVadSensitivity sensitivity) =>
      vadSensitivities.add(sensitivity);

  @override
  Stream<CoreEvent> get events => _events.stream;

  /// Whether anyone listens to [events] (the FFI client registers its native
  /// callback only then).
  bool get hasEventListeners => _events.hasListener;

  /// Delivers [event] as the core would.
  void emitEvent(CoreEvent event) => _events.add(event);

  /// Delivers an undecodable payload as the core would.
  void emitInvalidEvent() =>
      _events.addError(const VoiceCoreException('invalid event payload'));

  @override
  void dispose() {
    disposed = true;
    // Not awaited: close() never completes for a stream nobody listened to.
    unawaited(_events.close());
  }
}
