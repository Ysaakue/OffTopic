import 'package:flutter_test/flutter_test.dart';
import 'package:voice_core/voice_core.dart';

void main() {
  test('VoiceCoreException describes itself with its message', () {
    const exception = VoiceCoreException('core not started');

    expect(exception.message, 'core not started');
    expect(exception.toString(), 'VoiceCoreException: core not started');
  });
}
