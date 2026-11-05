import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/entities/room_request.dart';
import 'package:offtopic/features/room/domain/entities/session_stats.dart';
import 'package:offtopic/features/room/domain/value_objects/display_name.dart';
import 'package:offtopic/features/room/domain/value_objects/host_address.dart';
import 'package:offtopic/features/settings/domain/entities/talk_settings.dart';
import 'package:voice_core/voice_core.dart';

final DisplayName riderName = DisplayName.tryParse('Rider')!;
final HostAddress hostAddress = HostAddress.tryParse('192.168.43.1')!;

final joinRequest = JoinRoomRequest(name: riderName, host: hostAddress);
final hostRequest = HostRoomRequest(name: riderName);
final echoRequest = HostRoomRequest(name: riderName, echoMode: true);

final hotspotAddress = LocalAddress(
  kind: LocalNetworkKind.hotspot,
  address: hostAddress,
);
final wifiAddress = LocalAddress(
  kind: LocalNetworkKind.wifi,
  address: HostAddress.tryParse('192.168.1.20')!,
);

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
  captureOverruns: 6,
  // 20 ms frame + half of the 42 ms round trip + 60 ms of jitter buffer.
  estimatedDelayMs: 101,
);

const defaultTalk = TalkSettings();
const pushToTalkSettings = TalkSettings(
  mode: TalkMode.pushToTalk,
  sensitivity: VadSensitivity.high,
);

/// Statistics with the given round trip and delay estimate, the rest zero.
SessionStats statsWith({required int? rttMs, required int? delayMs}) =>
    SessionStats(
      participants: 1,
      lossPct: 0,
      jitterMs: 1,
      jitterBufferMs: 40,
      jitterTargetMs: 40,
      rttMs: rttMs,
      inputLevel: 0,
      packetsSent: 0,
      packetsReceived: 0,
      packetsLost: 0,
      packetsLate: 0,
      fecRecovered: 0,
      concealedFrames: 0,
      playoutUnderruns: 0,
      estimatedDelayMs: delayMs,
    );
