#include "api/config_mapper.h"

namespace voice_core::api {
namespace {

int32_t toFlag(bool value) noexcept { return value ? 1 : 0; }

std::string copyString(const char* text) { return text == nullptr ? std::string() : text; }

}  // namespace

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
}

}  // namespace voice_core::api
