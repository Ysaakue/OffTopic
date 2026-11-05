import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:voice_core/src/event_decoder.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/src/models/core_defaults.dart';
import 'package:voice_core/src/models/core_event.dart';
import 'package:voice_core/src/models/core_stats.dart';
import 'package:voice_core/src/models/voice_controls.dart';
import 'package:voice_core/src/native_mappers.dart';
import 'package:voice_core/src/voice_core_client.dart';
import 'package:voice_core/src/voice_core_exception.dart';
import 'package:voice_core/src/voice_core_library_loader.dart';

/// Native signature of vc_event_callback.
typedef EventCallbackNative = Void Function(Int32 event, Pointer<Char> payload);

/// [VoiceCoreClient] backed by the C API of `libvoice_core`.
///
/// Events arrive through a `NativeCallable.listener`, which the core may call
/// from any of its threads. Every payload is owned by Dart and released with
/// vc_free_event_payload exactly once, even when decoding fails.
final class FfiVoiceCoreClient implements VoiceCoreClient {
  /// Wraps already loaded bindings; tests pass a mock here.
  new(this._bindings, {this._decoder = const EventDecoder()});

  /// Loads the native library for the current platform and wraps it.
  factory open({
    VoiceCoreLibraryLoader loader = const VoiceCoreLibraryLoader(),
  }) => FfiVoiceCoreClient(VoiceCoreBindings(loader.load()));

  final VoiceCoreBindings _bindings;
  final EventDecoder _decoder;
  NativeCallable<EventCallbackNative>? _callback;

  late final StreamController<CoreEvent> _events =
      StreamController<CoreEvent>.broadcast(
        onListen: _registerCallback,
        onCancel: _unregisterCallback,
      );

  @override
  String get version {
    final pointer = _bindings.vc_version();
    if (pointer == nullptr) {
      throw const VoiceCoreException('vc_version returned a null pointer.');
    }
    // The string is static inside the core: it must not be freed here.
    return pointer.cast<Utf8>().toDartString();
  }

  @override
  CoreDefaults get defaults => using((arena) {
    final config = arena<vc_config>();
    _bindings.vc_config_defaults(config);
    return config.ref.toDefaults();
  });

  @override
  CoreStats? readStats() => using((arena) {
    final stats = arena<vc_stats>();
    final result = _bindings.vc_get_stats(stats);
    if (result == vc_result.VC_ERR_INVALID_STATE.value) {
      return null; // no session is running
    }
    if (result != vc_result.VC_OK.value) {
      throw VoiceCoreException('vc_get_stats failed with $result.');
    }
    return stats.ref.toModel();
  });

  @override
  void setOutputGain(double gain) => _bindings.vc_set_output_gain(gain);

  @override
  void setTalkMode(CoreTalkMode mode) =>
      _check('vc_set_talk_mode', _bindings.vc_set_talk_mode(mode.native));

  @override
  void setPushToTalk({required bool pressed}) =>
      _bindings.vc_set_push_to_talk(pressed ? 1 : 0);

  @override
  void setVadSensitivity(CoreVadSensitivity sensitivity) => _check(
    'vc_set_vad_sensitivity',
    _bindings.vc_set_vad_sensitivity(sensitivity.native),
  );

  @override
  Stream<CoreEvent> get events => _events.stream;

  @override
  void dispose() {
    _unregisterCallback();
    // Not awaited: close() never completes for a stream nobody listened to.
    unawaited(_events.close());
  }

  void _registerCallback() {
    final callback = NativeCallable<EventCallbackNative>.listener(_onEvent);
    _callback = callback;
    _bindings.vc_set_event_callback(callback.nativeFunction);
  }

  void _unregisterCallback() {
    final callback = _callback;
    if (callback == null) {
      return;
    }
    // The core guarantees no further call once this returns.
    _bindings.vc_set_event_callback(nullptr);
    callback.close();
    _callback = null;
  }

  void _onEvent(int type, Pointer<Char> payload) {
    try {
      final event = _decoder.decode(type, _takePayload(payload));
      if (event != null) {
        _events.add(event);
      }
    } on VoiceCoreException catch (error) {
      _events.addError(error);
    }
  }

  void _check(String function, int result) {
    if (result != vc_result.VC_OK.value) {
      throw VoiceCoreException('$function failed with $result.');
    }
  }

  String _takePayload(Pointer<Char> payload) {
    if (payload == nullptr) {
      throw const VoiceCoreException('The core sent an event without payload.');
    }
    try {
      return payload.cast<Utf8>().toDartString();
    } on FormatException catch (error) {
      throw VoiceCoreException('Event payload is not UTF-8: ${error.message}');
    } finally {
      _bindings.vc_free_event_payload(payload);
    }
  }
}
