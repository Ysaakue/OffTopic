#include "api/config_mapper.h"

namespace voice_core::api {
namespace {

int32_t toFlag(bool value) noexcept { return value ? 1 : 0; }

std::string copyString(const char* text) { return text == nullptr ? std::string() : text; }

// The C values are checked before the cast: a cast to an enum with a fixed
// underlying type would wrap (e.g. 260 -> 4) instead of failing validation.
template <typename Enum>
std::optional<Enum> toEnum(int32_t value, Enum last) noexcept {
  if (value < 0 || value > static_cast<int32_t>(last)) {
    return std::nullopt;
  }
  return static_cast<Enum>(value);
}

}  // namespace

std::optional<NoiseSuppression> toNoiseSuppression(int32_t value) noexcept {
  return toEnum(value, NoiseSuppression::kVeryHigh);
}

std::optional<TalkMode> toTalkMode(int32_t value) noexcept {
  return toEnum(value, TalkMode::kPushToTalk);
}

std::optional<VadSensitivity> toVadSensitivity(int32_t value) noexcept {
  return toEnum(value, VadSensitivity::kHigh);
}

void fillDefaults(vc_config* out) noexcept {
  const CoreConfig defaults;
  *out = vc_config{};
  out->role = VC_ROLE_CLIENT;
  out->host_ip = nullptr;
  out->display_name = nullptr;
  out->control_port = defaults.controlPort;
  out->audio_port = defaults.audioPort;
  out->sample_rate_hz = defaults.sampleRateHz;
  out->frame_samples = defaults.frameSamples;
  out->bitrate_bps = defaults.bitrateBps;
  out->fec_enabled = toFlag(defaults.fecEnabled);
  out->expected_loss_pct = defaults.expectedLossPct;
  out->dtx_enabled = toFlag(defaults.dtxEnabled);
  out->jitter_min_ms = defaults.jitterMinMs;
  out->jitter_initial_ms = defaults.jitterInitialMs;
  out->jitter_max_ms = defaults.jitterMaxMs;
  out->keepalive_interval_ms = defaults.keepaliveIntervalMs;
  out->peer_timeout_ms = defaults.peerTimeoutMs;
  out->echo_mode = toFlag(defaults.echoMode);
  out->noise_suppression = static_cast<int32_t>(defaults.noiseSuppression);
  out->automatic_gain = toFlag(defaults.automaticGain);
  out->echo_cancellation = toFlag(defaults.echoCancellation);
  out->talk_mode = static_cast<int32_t>(defaults.talkMode);
  out->vad_sensitivity = static_cast<int32_t>(defaults.vadSensitivity);
  out->vad_tail_ms = defaults.vadTailMs;
}

Expected<CoreConfig> toCoreConfig(const vc_config& in) {
  if (in.role != VC_ROLE_CLIENT && in.role != VC_ROLE_HOST) {
    return Status::kInvalidArgument;
  }
  CoreConfig config;
  config.role = in.role == VC_ROLE_HOST ? Role::kHost : Role::kClient;
  config.hostIp = copyString(in.host_ip);
  config.displayName = copyString(in.display_name);
  config.controlPort = in.control_port;
  config.audioPort = in.audio_port;
  config.sampleRateHz = in.sample_rate_hz;
  config.frameSamples = in.frame_samples;
  config.bitrateBps = in.bitrate_bps;
  config.fecEnabled = in.fec_enabled != 0;
  config.expectedLossPct = in.expected_loss_pct;
  config.dtxEnabled = in.dtx_enabled != 0;
  config.jitterMinMs = in.jitter_min_ms;
  config.jitterInitialMs = in.jitter_initial_ms;
  config.jitterMaxMs = in.jitter_max_ms;
  config.keepaliveIntervalMs = in.keepalive_interval_ms;
  config.peerTimeoutMs = in.peer_timeout_ms;
  config.echoMode = in.echo_mode != 0;
  const std::optional<NoiseSuppression> noiseSuppression = toNoiseSuppression(in.noise_suppression);
  const std::optional<TalkMode> talkMode = toTalkMode(in.talk_mode);
  const std::optional<VadSensitivity> vadSensitivity = toVadSensitivity(in.vad_sensitivity);
  if (!noiseSuppression || !talkMode || !vadSensitivity) {
    return Status::kInvalidArgument;
  }
  config.noiseSuppression = *noiseSuppression;
  config.automaticGain = in.automatic_gain != 0;
  config.echoCancellation = in.echo_cancellation != 0;
  config.talkMode = *talkMode;
  config.vadSensitivity = *vadSensitivity;
  config.vadTailMs = in.vad_tail_ms;
  if (validate(config) != ConfigError::kNone) {
    return Status::kInvalidArgument;
  }
  return config;
}

void toVcStats(const EngineStats& in, vc_stats* out) noexcept {
  const SessionStats& session = in.session;
  out->participants = session.linkUp ? 1 : 0;
  out->loss_pct = session.lossPct;
  out->jitter_ms = session.jitterMs;
  out->jitter_buffer_ms = session.jitterBufferMs;
  out->jitter_target_ms = session.jitterTargetMs;
  out->rtt_ms = session.rttMs;
  out->input_level = session.inputLevel;
  out->packets_sent = session.packetsSent;
  out->packets_received = session.packetsReceived;
  out->packets_lost = session.packetsLost;
  out->packets_late = session.packetsLate;
  out->fec_recovered = session.fecRecovered;
  out->concealed_frames = session.concealedFrames;
  out->playout_underruns = in.playoutUnderruns;
  out->capture_overruns = in.captureOverruns;
  out->playout_queue_ms = in.playoutQueueMs;
}

}  // namespace voice_core::api
