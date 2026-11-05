import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  final started = DateTime(2026, 11, 4, 20);
  final report = SessionReport(
    request: joinRequest,
    talk: defaultTalk,
    startedAt: started,
  );

  group('Spread', () {
    test('is empty at first', () {
      const spread = Spread();

      expect(spread.count, 0);
      expect(spread.average, isNull);
      expect(spread.min, isNull);
      expect(spread.max, isNull);
    });

    test('keeps the minimum, average and maximum', () {
      final spread = const Spread().add(40).add(10).add(25);

      expect(spread.count, 3);
      expect(spread.min, 10);
      expect(spread.max, 40);
      expect(spread.average, 25);
      expect(spread, const Spread().add(40).add(10).add(25));
    });
  });

  test('aggregates the statistics and keeps the latest totals', () {
    final next = report
        .withStats(sampleSessionStats)
        .withStats(statsWith(rttMs: 10, delayMs: 50));

    expect(next.delay.count, 2);
    expect(next.delay.max, 101);
    expect(next.roundTrip.min, 10);
    expect(next.loss.count, 2);
    expect(next.jitterBuffer.count, 2);
    expect(next.last?.rttMs, 10);
  });

  test('skips the delay and the round trip until they are known', () {
    final next = report.withStats(statsWith(rttMs: null, delayMs: null));

    expect(next.delay.count, 0);
    expect(next.roundTrip.count, 0);
    expect(next.jitter.count, 1);
  });

  test('records each new route once, in order', () {
    final next = report
        .withAudio(const RoomAudio(route: AudioRoute.speaker))
        .withAudio(const RoomAudio(route: AudioRoute.speaker, systemCall: true))
        .withAudio(const RoomAudio(route: AudioRoute.intercom));

    expect(next.routes, [AudioRoute.speaker, AudioRoute.intercom]);
    expect(next.audio, const RoomAudio(route: AudioRoute.intercom));
  });

  test('counts the link drops', () {
    final next = report
        .withLink(const RoomLink(up: true, peer: 'a'))
        .withLink(const RoomLink(up: false, peer: 'a'))
        .withLink(const RoomLink(up: true, peer: 'a'))
        .withLink(const RoomLink(up: false, peer: 'a'));

    expect(next.linkDrops, 2);
  });

  test('follows the talk settings, the device and the end', () {
    const info = AppInfo(
      coreVersion: '0.1.0',
      manufacturer: 'samsung',
      model: 'SM-A546E',
      osName: 'android',
      osVersion: '16',
    );
    final ended = started.add(const Duration(minutes: 10));

    final next = report
        .withTalk(const TalkSettings(mode: TalkMode.pushToTalk))
        .withAppInfo(info)
        .ended(ended);

    expect(next.talk.mode, TalkMode.pushToTalk);
    expect(next.appInfo, info);
    expect(next.duration(ended.add(const Duration(hours: 1))).inMinutes, 10);
    expect(report.duration(ended).inMinutes, 10);
  });
}
