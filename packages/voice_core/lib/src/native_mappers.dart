import 'package:voice_core/src/generated/voice_core_bindings.g.dart';
import 'package:voice_core/src/models/core_defaults.dart';
import 'package:voice_core/src/models/core_stats.dart';
import 'package:voice_core/src/models/voice_controls.dart';

/// Converts vc_config (as filled by vc_config_defaults) to [CoreDefaults].
extension VcConfigToDefaults on vc_config {
  /// The defaults carried by this struct.
  CoreDefaults toDefaults() => CoreDefaults(
    controlPort: control_port,
    audioPort: audio_port,
    sampleRateHz: sample_rate_hz,
    frameSamples: frame_samples,
    bitrateBps: bitrate_bps,
    jitterMinMs: jitter_min_ms,
    jitterInitialMs: jitter_initial_ms,
    jitterMaxMs: jitter_max_ms,
    keepaliveIntervalMs: keepalive_interval_ms,
    peerTimeoutMs: peer_timeout_ms,
  );
}

/// Converts vc_stats to [CoreStats].
extension VcStatsToModel on vc_stats {
  /// The core reports an unknown RTT as -1.
  static const unknownRtt = -1;

  /// The snapshot carried by this struct.
  CoreStats toModel() => CoreStats(
    participants: participants,
    lossPct: loss_pct,
    jitterMs: jitter_ms,
    jitterBufferMs: jitter_buffer_ms,
    jitterTargetMs: jitter_target_ms,
    rttMs: rtt_ms == unknownRtt ? null : rtt_ms,
    inputLevel: input_level,
    packetsSent: packets_sent,
    packetsReceived: packets_received,
    packetsLost: packets_lost,
    packetsLate: packets_late,
    fecRecovered: fec_recovered,
    concealedFrames: concealed_frames,
    playoutUnderruns: playout_underruns,
    captureOverruns: capture_overruns,
    playoutQueueMs: playout_queue_ms,
  );
}

/// The vc_talk_mode value of a [CoreTalkMode].
extension CoreTalkModeToNative on CoreTalkMode {
  /// The C enum value.
  int get native => switch (this) {
    CoreTalkMode.voice => vc_talk_mode.VC_TALK_MODE_VOICE.value,
    CoreTalkMode.pushToTalk => vc_talk_mode.VC_TALK_MODE_PUSH_TO_TALK.value,
  };
}

/// The vc_vad_sensitivity value of a [CoreVadSensitivity].
extension CoreVadSensitivityToNative on CoreVadSensitivity {
  /// The C enum value.
  int get native => switch (this) {
    CoreVadSensitivity.low => vc_vad_sensitivity.VC_VAD_SENSITIVITY_LOW.value,
    CoreVadSensitivity.medium =>
      vc_vad_sensitivity.VC_VAD_SENSITIVITY_MEDIUM.value,
    CoreVadSensitivity.high => vc_vad_sensitivity.VC_VAD_SENSITIVITY_HIGH.value,
  };
}
