import 'dart:convert';

import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/src/models/core_event.dart';
import 'package:voice_core/src/voice_core_exception.dart';

/// Turns an event delivered by the core (type + JSON payload, see
/// voice_core.h) into a [CoreEvent].
final class EventDecoder {
  /// Creates a decoder.
  const new();

  /// The decoded event, or null for a type this version does not know
  /// (forward compatibility). Throws [VoiceCoreException] when the payload
  /// is not the JSON documented for its type.
  CoreEvent? decode(int type, String payload) {
    if (type == vc_event_type.VC_EVENT_STATE_CHANGED.value) {
      return _stateChanged(_object(payload));
    }
    if (type == vc_event_type.VC_EVENT_LINK_CHANGED.value) {
      return _linkChanged(_object(payload));
    }
    return null;
  }

  Map<String, Object?> _object(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (error) {
      throw VoiceCoreException('Invalid event JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw VoiceCoreException('Event payload is not a JSON object: $payload');
    }
    return decoded;
  }

  CoreStateChanged _stateChanged(Map<String, Object?> json) {
    final name = _field<String>(json, 'state');
    final state = CoreState.values.where((s) => s.name == name).firstOrNull;
    if (state == null) {
      throw VoiceCoreException('Unknown core state "$name".');
    }
    final error = json['error'];
    if (error != null && error is! int) {
      throw const VoiceCoreException('"error" must be an integer.');
    }
    return CoreStateChanged(state, errorCode: error as int?);
  }

  CoreLinkChanged _linkChanged(Map<String, Object?> json) => CoreLinkChanged(
    up: _field<bool>(json, 'up'),
    peer: _field<String>(json, 'peer'),
  );

  T _field<T>(Map<String, Object?> json, String name) {
    final value = json[name];
    if (value is! T) {
      throw VoiceCoreException('Event field "$name" is missing or not a $T.');
    }
    return value;
  }
}
