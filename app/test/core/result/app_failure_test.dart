import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';

void main() {
  group('CoreFailure', () {
    test('keeps its message and compares by value', () {
      const failure = CoreFailure('vc_version returned null');

      expect(failure.message, 'vc_version returned null');
      expect(failure, const CoreFailure('vc_version returned null'));
      expect(failure, isA<Exception>());
    });
  });

  group('PlatformFailure', () {
    test('keeps code and message', () {
      const failure = PlatformFailure(code: 'denied', message: 'no access');

      expect(failure.code, 'denied');
      expect(failure.message, 'no access');
    });

    test('falls back to the code as message', () {
      const failure = PlatformFailure(code: 'channel-error');

      expect(failure.message, 'channel-error');
    });

    test('compares code and message', () {
      const failure = PlatformFailure(code: 'a', message: 'm');

      expect(failure, const PlatformFailure(code: 'a', message: 'm'));
      expect(failure, isNot(const PlatformFailure(code: 'b', message: 'm')));
    });
  });
}
