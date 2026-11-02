#include "api/config_mapper.h"

#include <gtest/gtest.h>

namespace voice_core::api {
namespace {

vc_config validClient() {
  vc_config config;
  fillDefaults(&config);
  config.host_ip = "192.168.43.1";
  config.display_name = "Ana";
  return config;
}

TEST(ConfigMapperTest, DefaultsMirrorCoreConfig) {
  const CoreConfig core;
  vc_config config;

  fillDefaults(&config);

  EXPECT_EQ(config.role, VC_ROLE_CLIENT);
  EXPECT_EQ(config.host_ip, nullptr);
  EXPECT_EQ(config.display_name, nullptr);
  EXPECT_EQ(config.control_port, core.controlPort);
  EXPECT_EQ(config.audio_port, core.audioPort);
  EXPECT_EQ(config.sample_rate_hz, core.sampleRateHz);
  EXPECT_EQ(config.frame_samples, core.frameSamples);
  EXPECT_EQ(config.bitrate_bps, core.bitrateBps);
  EXPECT_EQ(config.fec_enabled, 1);
  EXPECT_EQ(config.expected_loss_pct, core.expectedLossPct);
  EXPECT_EQ(config.dtx_enabled, 1);
  EXPECT_EQ(config.jitter_min_ms, core.jitterMinMs);
  EXPECT_EQ(config.jitter_initial_ms, core.jitterInitialMs);
  EXPECT_EQ(config.jitter_max_ms, core.jitterMaxMs);
  EXPECT_EQ(config.keepalive_interval_ms, core.keepaliveIntervalMs);
  EXPECT_EQ(config.peer_timeout_ms, core.peerTimeoutMs);
  EXPECT_EQ(config.echo_mode, 0);
}

TEST(ConfigMapperTest, CopiesEveryField) {
  vc_config in = validClient();
  in.control_port = 50000;
  in.audio_port = 50001;
  in.bitrate_bps = 32000;
  in.fec_enabled = 0;
  in.expected_loss_pct = 20;
  in.dtx_enabled = 0;
  in.jitter_min_ms = 40;
  in.jitter_initial_ms = 60;
  in.jitter_max_ms = 200;
  in.keepalive_interval_ms = 500;
  in.peer_timeout_ms = 3000;

  const Expected<CoreConfig> out = toCoreConfig(in);

  ASSERT_TRUE(out.hasValue());
  const CoreConfig& core = out.value();
  EXPECT_EQ(core.role, Role::kClient);
  EXPECT_EQ(core.hostIp, "192.168.43.1");
  EXPECT_EQ(core.displayName, "Ana");
  EXPECT_EQ(core.controlPort, 50000);
  EXPECT_EQ(core.audioPort, 50001);
  EXPECT_EQ(core.bitrateBps, 32000);
  EXPECT_FALSE(core.fecEnabled);
  EXPECT_EQ(core.expectedLossPct, 20);
  EXPECT_FALSE(core.dtxEnabled);
  EXPECT_EQ(core.jitterMinMs, 40);
  EXPECT_EQ(core.jitterInitialMs, 60);
  EXPECT_EQ(core.jitterMaxMs, 200);
  EXPECT_EQ(core.keepaliveIntervalMs, 500);
  EXPECT_EQ(core.peerTimeoutMs, 3000);
  EXPECT_FALSE(core.echoMode);
}

TEST(ConfigMapperTest, MapsTheHostWithEchoAndNoHostIp) {
  vc_config in = validClient();
  in.role = VC_ROLE_HOST;
  in.host_ip = nullptr;
  in.echo_mode = 1;

  const Expected<CoreConfig> out = toCoreConfig(in);

  ASSERT_TRUE(out.hasValue());
  EXPECT_EQ(out.value().role, Role::kHost);
  EXPECT_TRUE(out.value().hostIp.empty());
  EXPECT_TRUE(out.value().echoMode);
}

TEST(ConfigMapperTest, RejectsAnUnknownRole) {
  vc_config in = validClient();
  in.role = 7;

  EXPECT_EQ(toCoreConfig(in).status(), Status::kInvalidArgument);
}

TEST(ConfigMapperTest, RejectsAnInvalidField) {
  vc_config in = validClient();
  in.display_name = nullptr;

  EXPECT_EQ(toCoreConfig(in).status(), Status::kInvalidArgument);
}

TEST(ConfigMapperTest, CopiesEveryStatistic) {
  EngineStats in;
  in.session.linkUp = true;
  in.session.lossPct = 1.5F;
  in.session.jitterMs = 2.5F;
  in.session.jitterBufferMs = 60;
  in.session.jitterTargetMs = 40;
  in.session.rttMs = 33;
  in.session.inputLevel = 0.25F;
  in.session.packetsSent = 1;
  in.session.packetsReceived = 2;
  in.session.packetsLost = 3;
  in.session.packetsLate = 4;
  in.session.fecRecovered = 5;
  in.session.concealedFrames = 6;
  in.playoutUnderruns = 7;
  in.captureOverruns = 8;
  vc_stats out{};

  toVcStats(in, &out);

  EXPECT_EQ(out.participants, 1);
  EXPECT_FLOAT_EQ(out.loss_pct, 1.5F);
  EXPECT_FLOAT_EQ(out.jitter_ms, 2.5F);
  EXPECT_EQ(out.jitter_buffer_ms, 60);
  EXPECT_EQ(out.jitter_target_ms, 40);
  EXPECT_EQ(out.rtt_ms, 33);
  EXPECT_FLOAT_EQ(out.input_level, 0.25F);
  EXPECT_EQ(out.packets_sent, 1U);
  EXPECT_EQ(out.packets_received, 2U);
  EXPECT_EQ(out.packets_lost, 3U);
  EXPECT_EQ(out.packets_late, 4U);
  EXPECT_EQ(out.fec_recovered, 5U);
  EXPECT_EQ(out.concealed_frames, 6U);
  EXPECT_EQ(out.playout_underruns, 7U);
  EXPECT_EQ(out.capture_overruns, 8U);

  in.session.linkUp = false;
  toVcStats(in, &out);
  EXPECT_EQ(out.participants, 0);
}

}  // namespace
}  // namespace voice_core::api
