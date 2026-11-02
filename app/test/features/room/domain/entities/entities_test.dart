import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/room/domain/entities/room_link.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';

import '../../../../helpers/room_fixtures.dart';

void main() {
  test('room requests compare by value', () {
    expect(HostRoomRequest(name: riderName), hostRequest);
    expect(hostRequest, isNot(echoRequest));
    expect(JoinRoomRequest(name: riderName, host: hostAddress), joinRequest);
    expect(echoRequest.echoMode, isTrue);
    expect(joinRequest.host, hostAddress);
  });

  test('session stats know whether the link is up', () {
    const idle = SessionStats(
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
    );

    expect(sampleSessionStats.linkUp, isTrue);
    expect(idle.linkUp, isFalse);
    expect(idle, isNot(sampleSessionStats));
    expect(idle.rttMs, isNull);
  });

  test('room links compare by value', () {
    expect(
      const RoomLink(up: true, peer: 'a:1'),
      const RoomLink(up: true, peer: 'a:1'),
    );
    expect(
      const RoomLink(up: true, peer: 'a:1'),
      isNot(const RoomLink(up: false, peer: 'a:1')),
    );
  });
}
