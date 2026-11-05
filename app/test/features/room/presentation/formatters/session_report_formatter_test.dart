import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';
import 'package:offtopic/features/room/domain/entities/audio_route.dart';
import 'package:offtopic/features/room/domain/entities/room_audio.dart';
import 'package:offtopic/features/room/domain/entities/session_report.dart';
import 'package:offtopic/features/room/presentation/formatters/session_report_formatter.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  const formatter = SessionReportFormatter();
  final started = DateTime(2026, 11, 4, 20);

  test('describes a finished room with its statistics', () {
    final report =
        SessionReport(
              request: joinRequest,
              talk: pushToTalkSettings,
              startedAt: started,
            )
            .withAppInfo(
              const AppInfo(
                coreVersion: '0.1.0',
                manufacturer: 'samsung',
                model: 'SM-A546E',
                osName: 'android',
                osVersion: '16',
              ),
            )
            .withAudio(
              const RoomAudio(route: AudioRoute.speaker, systemCall: true),
            )
            .withAudio(
              const RoomAudio(route: AudioRoute.intercom, systemCall: true),
            )
            .withStats(sampleSessionStats)
            .ended(started.add(const Duration(minutes: 10, seconds: 5)));

    final text = formatter.format(report, started.add(const Duration(days: 1)));

    expect(text, '''
OffTopic room report
device: samsung SM-A546E · android 16 · core 0.1.0
role: client of 192.168.43.1
talk: pushToTalk · sensitivity high
call mode: system call
routes: speaker > intercom
duration: 10:05
link drops: 0
delay estimate ms (network and buffers, without the phones' audio hardware): min 101.0 · avg 101.0 · max 101.0
round trip ms: min 42.0 · avg 42.0 · max 42.0
jitter ms: min 3.5 · avg 3.5 · max 3.5
jitter buffer ms: min 60.0 · avg 60.0 · max 60.0
loss %: min 1.3 · avg 1.3 · max 1.3
packets: sent 100 · received 98 · lost 2 · late 1
recovered: fec 3 · concealed 4
audio: underruns 5 · overruns 6
''');
  });

  test('marks a running room and the missing data', () {
    final report = SessionReport(
      request: echoRequest,
      talk: defaultTalk,
      startedAt: started,
    );

    final text = formatter.format(
      report,
      started.add(const Duration(seconds: 7)),
    );

    expect(text, contains('role: host (echo mode)'));
    expect(text, contains('call mode: direct routing'));
    expect(text, contains('routes: none'));
    expect(text, contains('duration: 0:07 (running)'));
    expect(text, contains('round trip ms: n/a'));
    expect(text, isNot(contains('device:')));
    expect(text, isNot(contains('packets:')));
  });

  test('names a plain host', () {
    final report = SessionReport(
      request: hostRequest,
      talk: defaultTalk,
      startedAt: started,
    );

    expect(formatter.format(report, started), contains('role: host\n'));
  });
}
