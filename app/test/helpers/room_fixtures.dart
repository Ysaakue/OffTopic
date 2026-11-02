import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/value_objects/display_name.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';
import 'package:voice_core/voice_core.dart';

final DisplayName riderName = DisplayName.tryParse('Rider')!;
final HostAddress hostAddress = HostAddress.tryParse('192.168.43.1')!;

final joinRequest = JoinRoomRequest(name: riderName, host: hostAddress);
final hostRequest = HostRoomRequest(name: riderName);
final echoRequest = HostRoomRequest(name: riderName, echoMode: true);

const sampleCoreStats = CoreStats(
  participants: 1,
  lossPct: 1.25,
  jitterMs: 3.5,
  jitterBufferMs: 60,
  jitterTargetMs: 40,
  rttMs: 42,
  inputLevel: 0.5,
  packetsSent: 100,
  packetsReceived: 98,
  packetsLost: 2,
  packetsLate: 1,
  fecRecovered: 3,
  concealedFrames: 4,
  playoutUnderruns: 5,
  captureOverruns: 6,
);

const sampleSessionStats = SessionStats(
  participants: 1,
  lossPct: 1.25,
  jitterMs: 3.5,
  jitterBufferMs: 60,
  jitterTargetMs: 40,
  rttMs: 42,
  inputLevel: 0.5,
  packetsSent: 100,
  packetsReceived: 98,
  packetsLost: 2,
  packetsLate: 1,
  fecRecovered: 3,
  concealedFrames: 4,
  playoutUnderruns: 5,
);
