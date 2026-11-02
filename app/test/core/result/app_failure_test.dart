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

  group('PermissionFailure', () {
    test('says whether the system will ask again', () {
      const failure = PermissionFailure(permanentlyDenied: true);

      expect(failure.permanentlyDenied, isTrue);
      expect(failure, isNot(const PermissionFailure(permanentlyDenied: false)));
    });
  });

  group('RoomFailure', () {
    test('keeps its reason and message', () {
      const failure = RoomFailure(RoomFailureReason.network, 'no socket');

      expect(failure.reason, RoomFailureReason.network);
      expect(failure.message, 'no socket');
      expect(
        failure,
        isNot(const RoomFailure(RoomFailureReason.audioDevice, 'no socket')),
      );
    });
  });
}
