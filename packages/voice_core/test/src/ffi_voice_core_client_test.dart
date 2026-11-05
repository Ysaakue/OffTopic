import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/voice_core.dart';

import '../support/mock_voice_core_bindings.dart';

void main() {
  setUpAll(registerBindingFallbacks);

  group('FfiVoiceCoreClient', () {
    late MockVoiceCoreBindings bindings;
    late NativeStrings strings;

    setUp(() {
      bindings = MockVoiceCoreBindings();
      strings = NativeStrings();
    });

    tearDown(() => strings.freeAll());

    test('decodes the UTF-8 version string returned by vc_version', () {
      when(bindings.vc_version).thenReturn(strings.allocate('0.1.0'));

      expect(FfiVoiceCoreClient(bindings).version, '0.1.0');
    });

    test('reads the version from the core on every access', () {
      when(bindings.vc_version).thenReturn(strings.allocate('0.1.0'));
      final client = FfiVoiceCoreClient(bindings)..version;

      when(bindings.vc_version).thenReturn(strings.allocate('0.2.0'));

      expect(client.version, '0.2.0');
      verify(bindings.vc_version).called(2);
    });

    test('throws a VoiceCoreException on a null pointer', () {
      when(bindings.vc_version).thenReturn(nullptr);

      expect(
        () => FfiVoiceCoreClient(bindings).version,
        throwsA(
          isA<VoiceCoreException>().having(
            (e) => e.message,
            'message',
            contains('vc_version'),
          ),
        ),
      );
    });

    test('open loads the library through the given loader', () {
      final openedFiles = <String>[];
      final loader = VoiceCoreLibraryLoader(
        operatingSystem: 'android',
        openLibrary: (fileName) {
          openedFiles.add(fileName);
          return DynamicLibrary.executable();
        },
      );

      final client = FfiVoiceCoreClient.open(loader: loader);

      expect(client, isA<FfiVoiceCoreClient>());
      expect(openedFiles, [VoiceCoreLibraryLoader.androidLibraryName]);
    });

    test('open uses the platform loader by default', () {
      // Tests run on a desktop host, where the core is not packaged.
      expect(FfiVoiceCoreClient.open, throwsUnsupportedError);
    });
  });

  // Payload ownership (CLAUDE.md): the core allocates every payload and Dart
  // frees it exactly once with vc_free_event_payload, even when decoding fails.
  group('FfiVoiceCoreClient events', () {
    late MockVoiceCoreBindings bindings;
    late NativeCoreDouble core;
    late FfiVoiceCoreClient client;
    late List<CoreEvent> events;
    late List<Object> errors;

    setUp(() {
      bindings = MockVoiceCoreBindings();
      core = NativeCoreDouble(bindings);
      client = FfiVoiceCoreClient(bindings);
      events = [];
      errors = [];
      client.events.listen(events.add, onError: errors.add);
    });

    tearDown(() => client.dispose());

    test('frees every decoded payload once', () async {
      core
        ..sendJson(1, '{"state":"running"}')
        ..sendJson(2, '{"up":false,"peer":"10.0.0.2:5"}');
      await pumpEventQueue();

      expect(events, const [
        CoreStateChanged(CoreState.running),
        CoreLinkChanged(up: false, peer: '10.0.0.2:5'),
      ]);
      expect(core.freedPayloads, core.sentPayloads);
    });

    test('frees the payload when the JSON is invalid', () async {
      core.sendJson(1, '{"state":');
      await pumpEventQueue();

      expect(errors.single, isA<VoiceCoreException>());
      expect(core.freedPayloads, core.sentPayloads);
    });

    test('frees the payload when it is not UTF-8', () async {
      core.send(1, [0xC3, 0x28]);
      await pumpEventQueue();

      expect(
        errors.single,
        isA<VoiceCoreException>().having(
          (e) => e.message,
          'message',
          contains('UTF-8'),
        ),
      );
      expect(core.freedPayloads, core.sentPayloads);
    });

    test('frees and ignores an unknown event type', () async {
      core.sendJson(99, '{"future":true}');
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(errors, isEmpty);
      expect(core.freedPayloads, core.sentPayloads);
    });

    test('reports a missing payload without freeing anything', () async {
      core.callback.asFunction<void Function(int, Pointer<Char>)>()(1, nullptr);
      await pumpEventQueue();

      expect(errors.single, isA<VoiceCoreException>());
      expect(core.freedPayloads, isEmpty);
    });

    test('dispose unregisters the callback once', () {
      client
        ..dispose()
        ..dispose();

      expect(core.callbackRegistered, isFalse);
      verify(() => bindings.vc_set_event_callback(nullptr)).called(1);
    });
  });

  group('FfiVoiceCoreClient statistics', () {
    test('maps an unknown RTT to null', () {
      final bindings = MockVoiceCoreBindings();
      NativeCoreDouble(bindings).arrangeStatsResult(
        vc_result.VC_OK,
        const CoreStats(
          participants: 0,
          lossPct: 0,
          jitterMs: 0,
          jitterBufferMs: 0,
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
        ),
      );

      expect(FfiVoiceCoreClient(bindings).readStats()?.rttMs, isNull);
    });

    test('names the failing result code', () {
      final bindings = MockVoiceCoreBindings();
      NativeCoreDouble(bindings).arrangeStatsResult(vc_result.VC_ERR_INTERNAL);

      expect(
        FfiVoiceCoreClient(bindings).readStats,
        throwsA(
          isA<VoiceCoreException>().having(
            (e) => e.message,
            'message',
            contains('-6'),
          ),
        ),
      );
    });
  });

  group('FfiVoiceCoreClient voice controls', () {
    test('sends push to talk as 1 and 0', () {
      final bindings = MockVoiceCoreBindings();
      final core = NativeCoreDouble(bindings);
      final client = FfiVoiceCoreClient(bindings)..setPushToTalk(pressed: true);
      expect(core.pushToTalk, 1);

      client.setPushToTalk(pressed: false);
      expect(core.pushToTalk, 0);
    });

    test('names the control that the core refused', () {
      final bindings = MockVoiceCoreBindings();
      NativeCoreDouble(bindings).controlResult =
          vc_result.VC_ERR_INVALID_ARGUMENT;
      final client = FfiVoiceCoreClient(bindings);

      expect(
        () => client.setTalkMode(CoreTalkMode.voice),
        throwsA(
          isA<VoiceCoreException>().having(
            (e) => e.message,
            'message',
            contains('vc_set_talk_mode'),
          ),
        ),
      );
      expect(
        () => client.setVadSensitivity(CoreVadSensitivity.high),
        throwsA(isA<VoiceCoreException>()),
      );
    });
  });
}
