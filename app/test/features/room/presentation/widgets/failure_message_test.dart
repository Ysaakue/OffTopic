import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/features/room/presentation/widgets/failure_message.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('explains every failure', (tester) async {
    for (final (failure, text) in [
      (
        const RoomFailure(RoomFailureReason.alreadyActive, ''),
        'A test is already running.',
      ),
      (
        const RoomFailure(RoomFailureReason.invalidConfig, ''),
        'The voice core rejected the settings.',
      ),
      (
        const RoomFailure(RoomFailureReason.audioDevice, ''),
        'The microphone or the speaker could not be opened.',
      ),
      (
        const RoomFailure(RoomFailureReason.network, ''),
        'The network could not be opened. Check the Wi-Fi.',
      ),
      (
        const RoomFailure(RoomFailureReason.unavailable, ''),
        'The voice core is not available.',
      ),
      (
        const RoomFailure(RoomFailureReason.endedBySystem, ''),
        "The phone ended the room: another call, or the headset's "
            'hang-up button.',
      ),
      (const CoreFailure('x'), 'The voice core is not available.'),
    ]) {
      await tester.pumpLocalized(FailureMessage(failure: failure));

      expect(find.text(text), findsOneWidget, reason: '$failure');
    }
  });
}
