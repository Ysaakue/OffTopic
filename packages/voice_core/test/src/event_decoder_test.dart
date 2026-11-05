import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/voice_core.dart';

void main() {
  const decoder = EventDecoder();
  const stateChanged = 1;
  const linkChanged = 2;
  const talkingChanged = 3;

  group('EventDecoder', () {
    test('decodes every state', () {
      expect(
        decoder.decode(stateChanged, '{"state":"running"}'),
        const CoreStateChanged(CoreState.running),
      );
      expect(
        decoder.decode(stateChanged, '{"state":"stopped"}'),
        const CoreStateChanged(CoreState.stopped),
      );
      expect(
        decoder.decode(stateChanged, '{"state":"failed","error":-3}'),
        const CoreStateChanged(CoreState.failed, errorCode: -3),
      );
    });

    test('decodes link changes', () {
      expect(
        decoder.decode(linkChanged, '{"up":true,"peer":"192.168.43.1:47801"}'),
        const CoreLinkChanged(up: true, peer: '192.168.43.1:47801'),
      );
    });

    test('decodes talking changes', () {
      expect(
        decoder.decode(talkingChanged, '{"talking":true}'),
        const CoreTalkingChanged(talking: true),
      );
      expect(
        decoder.decode(talkingChanged, '{"talking":false}'),
        const CoreTalkingChanged(talking: false),
      );
      expect(
        () => decoder.decode(talkingChanged, '{"talking":1}'),
        throwsA(isA<VoiceCoreException>()),
      );
    });

    test('ignores unknown types and extra fields', () {
      expect(decoder.decode(42, 'anything'), isNull);
      expect(
        decoder.decode(stateChanged, '{"state":"running","new":1}'),
        const CoreStateChanged(CoreState.running),
      );
    });

    test('rejects payloads that do not follow the contract', () {
      for (final (type, payload) in [
        (stateChanged, 'not json'),
        (stateChanged, '[1, 2]'),
        (stateChanged, '{}'),
        (stateChanged, '{"state":7}'),
        (stateChanged, '{"state":"sleeping"}'),
        (stateChanged, '{"state":"failed","error":"x"}'),
        (linkChanged, '{"up":"yes","peer":"a"}'),
        (linkChanged, '{"up":true}'),
      ]) {
        expect(
          () => decoder.decode(type, payload),
          throwsA(isA<VoiceCoreException>()),
          reason: payload,
        );
      }
    });
  });

  group('CoreEvent', () {
    test('compares by value', () {
      expect(
        const CoreStateChanged(CoreState.failed, errorCode: -4),
        isNot(const CoreStateChanged(CoreState.failed, errorCode: -3)),
      );
      expect(
        const CoreLinkChanged(up: true, peer: 'a'),
        const CoreLinkChanged(up: true, peer: 'a'),
      );
    });
  });
}
