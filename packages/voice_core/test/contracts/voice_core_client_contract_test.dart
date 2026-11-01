import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:voice_core/testing.dart';
import 'package:voice_core/voice_core.dart';

import '../support/mock_voice_core_bindings.dart';
import 'voice_core_client_contract.dart';

void main() {
  voiceCoreClientContract('FfiVoiceCoreClient', _FfiHarness.new);
  voiceCoreClientContract('FakeVoiceCoreClient', _FakeHarness.new);
}

final class _FfiHarness implements VoiceCoreClientHarness {
  final _bindings = MockVoiceCoreBindings();
  final _strings = NativeStrings();

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
  void dispose() => _strings.freeAll();
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
  void dispose() {}
}
