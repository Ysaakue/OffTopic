import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_core/src/ffi_voice_core_client.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/voice_core.dart';

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

/// Fallback values for `any()` on the pointer parameters of the bindings.
void registerBindingFallbacks() {
  registerFallbackValue(nullptr.cast<vc_config>());
  registerFallbackValue(nullptr.cast<vc_stats>());
  registerFallbackValue(nullptr.cast<Char>());
  registerFallbackValue(nullptr.cast<NativeFunction<EventCallbackNative>>());
}

/// Plays the native core behind a [MockVoiceCoreBindings]: fills structs,
/// keeps the registered event callback and owns event payloads the way the
/// C++ EventDispatcher does (malloc'ed, freed by vc_free_event_payload).
final class NativeCoreDouble {
  new(this.bindings) {
    when(() => bindings.vc_set_event_callback(any())).thenAnswer((invocation) {
      callback =
          invocation.positionalArguments.single
              as Pointer<NativeFunction<EventCallbackNative>>;
    });
    when(() => bindings.vc_free_event_payload(any())).thenAnswer((invocation) {
      final payload = invocation.positionalArguments.single as Pointer<Char>;
      freedPayloads.add(payload.address);
      malloc.free(payload);
    });
    when(() => bindings.vc_set_output_gain(any())).thenAnswer((invocation) {
      outputGain = invocation.positionalArguments.single as double;
    });
  }

  final MockVoiceCoreBindings bindings;
  Pointer<NativeFunction<EventCallbackNative>> callback = nullptr.cast();
  final List<int> sentPayloads = [];
  final List<int> freedPayloads = [];
  double? outputGain;

  bool get callbackRegistered => callback != nullptr;

  void arrangeDefaults(CoreDefaults defaults) {
    when(() => bindings.vc_config_defaults(any())).thenAnswer((invocation) {
      (invocation.positionalArguments.single as Pointer<vc_config>).ref
        ..control_port = defaults.controlPort
        ..audio_port = defaults.audioPort
        ..sample_rate_hz = defaults.sampleRateHz
        ..frame_samples = defaults.frameSamples
        ..bitrate_bps = defaults.bitrateBps
        ..jitter_min_ms = defaults.jitterMinMs
        ..jitter_initial_ms = defaults.jitterInitialMs
        ..jitter_max_ms = defaults.jitterMaxMs
        ..keepalive_interval_ms = defaults.keepaliveIntervalMs
        ..peer_timeout_ms = defaults.peerTimeoutMs;
    });
  }

  void arrangeStatsResult(vc_result result, [CoreStats? stats]) {
    when(() => bindings.vc_get_stats(any())).thenAnswer((invocation) {
      if (stats != null) {
        (invocation.positionalArguments.single as Pointer<vc_stats>).ref
          ..participants = stats.participants
          ..loss_pct = stats.lossPct
          ..jitter_ms = stats.jitterMs
          ..jitter_buffer_ms = stats.jitterBufferMs
          ..jitter_target_ms = stats.jitterTargetMs
          ..rtt_ms = stats.rttMs ?? -1
          ..input_level = stats.inputLevel
          ..packets_sent = stats.packetsSent
          ..packets_received = stats.packetsReceived
          ..packets_lost = stats.packetsLost
          ..packets_late = stats.packetsLate
          ..fec_recovered = stats.fecRecovered
          ..concealed_frames = stats.concealedFrames
          ..playout_underruns = stats.playoutUnderruns
          ..capture_overruns = stats.captureOverruns;
      }
      return result.value;
    });
  }

  /// Calls the registered callback with a malloc'ed copy of [payloadBytes].
  void send(int type, List<int> payloadBytes) {
    final payload = malloc<Uint8>(payloadBytes.length + 1);
    payload.asTypedList(payloadBytes.length + 1)
      ..setAll(0, payloadBytes)
      ..[payloadBytes.length] = 0;
    sentPayloads.add(payload.address);
    callback.asFunction<void Function(int, Pointer<Char>)>()(
      type,
      payload.cast(),
    );
  }

  void sendJson(int type, String json) => send(type, utf8.encode(json));

  /// The JSON the core sends for [event] (voice_core.h).
  static (int, String) encode(CoreEvent event) => switch (event) {
    CoreStateChanged(:final state, :final errorCode) => (
      vc_event_type.VC_EVENT_STATE_CHANGED.value,
      jsonEncode({'state': state.name, 'error': ?errorCode}),
    ),
    CoreLinkChanged(:final up, :final peer) => (
      vc_event_type.VC_EVENT_LINK_CHANGED.value,
      jsonEncode({'up': up, 'peer': peer}),
    ),
  };
}
