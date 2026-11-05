import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/src/native_mappers.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';

import '../support/mock_voice_core_bindings.dart';
import 'voice_core_client_contract.dart';

void main() {
  registerBindingFallbacks();
  voiceCoreClientContract('FfiVoiceCoreClient', _FfiHarness.new);
  voiceCoreClientContract('FakeVoiceCoreClient', _FakeHarness.new);
}

final class _FfiHarness implements VoiceCoreClientHarness {
  // The core double stubs the bindings before the client ever calls them.
  new() {
    _core = NativeCoreDouble(_bindings);
  }

  final _bindings = MockVoiceCoreBindings();
  final _strings = NativeStrings();
  late final NativeCoreDouble _core;

  @override
  late final VoiceCoreClient client = FfiVoiceCoreClient(_bindings);

  @override
  void arrangeVersion(String version) {
    when(_bindings.vc_version).thenReturn(_strings.allocate(version));
  }

  @override
  void arrangeVersionUnavailable() {
    when(_bindings.vc_version).thenReturn(nullptr);
  }

  @override
  void arrangeDefaults(CoreDefaults defaults) =>
      _core.arrangeDefaults(defaults);

  @override
  void arrangeIdle() =>
      _core.arrangeStatsResult(vc_result.VC_ERR_INVALID_STATE);

  @override
  void arrangeStats(CoreStats stats) =>
      _core.arrangeStatsResult(vc_result.VC_OK, stats);

  @override
  void arrangeStatsFailure() =>
      _core.arrangeStatsResult(vc_result.VC_ERR_INTERNAL);

  @override
  void deliver(CoreEvent event) {
    final (type, json) = NativeCoreDouble.encode(event);
    _core.sendJson(type, json);
  }

  @override
  void deliverInvalid() =>
      _core.sendJson(vc_event_type.VC_EVENT_STATE_CHANGED.value, 'not json');

  @override
  bool get eventsRegistered => _core.callbackRegistered;

  @override
  double? get lastOutputGain => _core.outputGain;

  @override
  CoreTalkMode? get lastTalkMode => switch (_core.talkMode) {
    null => null,
    final mode => CoreTalkMode.values.firstWhere((m) => m.native == mode),
  };

  @override
  bool? get lastPushToTalk => switch (_core.pushToTalk) {
    null => null,
    final pressed => pressed != 0,
  };

  @override
  CoreVadSensitivity? get lastVadSensitivity => switch (_core.vadSensitivity) {
    null => null,
    final value => CoreVadSensitivity.values.firstWhere(
      (s) => s.native == value,
    ),
  };

  @override
  void dispose() {
    client.dispose();
    _strings.freeAll();
  }
}

final class _FakeHarness implements VoiceCoreClientHarness {
  final _fake = FakeVoiceCoreClient();

  @override
  VoiceCoreClient get client => _fake;

  @override
  void arrangeVersion(String version) => _fake.version = version;

  @override
  void arrangeVersionUnavailable() =>
      _fake.versionError = const VoiceCoreException('unavailable');

  @override
  void arrangeDefaults(CoreDefaults defaults) => _fake.defaults = defaults;

  @override
  void arrangeIdle() => _fake.stats = null;

  @override
  void arrangeStats(CoreStats stats) => _fake.stats = stats;

  @override
  void arrangeStatsFailure() =>
      _fake.statsError = const VoiceCoreException('failed');

  @override
  void deliver(CoreEvent event) => _fake.emitEvent(event);

  @override
  void deliverInvalid() => _fake.emitInvalidEvent();

  @override
  bool get eventsRegistered => _fake.hasEventListeners;

  @override
  double? get lastOutputGain =>
      _fake.outputGains.isEmpty ? null : _fake.outputGains.last;

  @override
  CoreTalkMode? get lastTalkMode => _fake.talkModes.lastOrNull;

  @override
  bool? get lastPushToTalk => _fake.pushToTalk.lastOrNull;

  @override
  CoreVadSensitivity? get lastVadSensitivity =>
      _fake.vadSensitivities.lastOrNull;

  @override
  void dispose() => _fake.dispose();
}
