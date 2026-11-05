import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

void main() {
  test('defaults to the voice detector at medium sensitivity', () {
    const settings = TalkSettings();

    expect(settings.mode, TalkMode.voice);
    expect(settings.sensitivity, VadSensitivity.medium);
  });

  test('copies with one field changed', () {
    const settings = TalkSettings();

    expect(
      settings.copyWith(mode: TalkMode.pushToTalk),
      const TalkSettings(mode: TalkMode.pushToTalk),
    );
    expect(
      settings.copyWith(sensitivity: VadSensitivity.low),
      const TalkSettings(sensitivity: VadSensitivity.low),
    );
    expect(settings.copyWith(), settings);
  });

  test('compares by value', () {
    expect(
      TalkSettings(mode: TalkMode.values.last),
      const TalkSettings(mode: TalkMode.pushToTalk),
    );
    expect(
      const TalkSettings(),
      isNot(const TalkSettings(sensitivity: VadSensitivity.high)),
    );
  });
}
