import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_platform/voice_platform.dart';

void main() {
  group('VoicePlatformException', () {
    test('keeps the code and message of a PlatformException', () {
      final exception = VoicePlatformException.fromPlatformException(
        PlatformException(code: 'boom', message: 'went wrong'),
      );

      expect(exception.code, 'boom');
      expect(exception.message, 'went wrong');
    });

    test('recognizes the not implemented code', () {
      const notImplemented = VoicePlatformException(
        code: VoicePlatformErrorCode.notImplemented,
      );
      const unsupported = VoicePlatformException(
        code: VoicePlatformErrorCode.unsupported,
      );

      expect(notImplemented.isNotImplemented, isTrue);
      expect(unsupported.isNotImplemented, isFalse);
    });

    test('describes itself with code and message', () {
      const withMessage = VoicePlatformException(code: 'x', message: 'detail');
      const withoutMessage = VoicePlatformException(code: 'x');

      expect(withMessage.toString(), 'VoicePlatformException(x): detail');
      expect(withoutMessage.toString(), 'VoicePlatformException(x): ');
    });

    test('shares the error codes used by the Kotlin host', () {
      expect(VoicePlatformErrorCode.notImplemented, 'not_implemented');
      expect(VoicePlatformErrorCode.channelError, 'channel-error');
    });
  });
}
