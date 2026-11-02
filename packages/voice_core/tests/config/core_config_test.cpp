#include "config/core_config.h"

#include <gtest/gtest.h>

#include <functional>
#include <string>
#include <vector>

namespace voice_core {
namespace {

CoreConfig validClient() {
  CoreConfig config;
  config.hostIp = "192.168.43.1";
  config.displayName = "Ana";
  return config;
}

CoreConfig validHost() {
  CoreConfig config;
  config.role = Role::kHost;
  config.displayName = "Bia";
  return config;
}

TEST(CoreConfigTest, DefaultsMatchTheSpecification) {
  const CoreConfig config;

  EXPECT_EQ(config.role, Role::kClient);
  EXPECT_EQ(config.sampleRateHz, 16000);
  EXPECT_EQ(config.frameSamples, 320);
  EXPECT_EQ(config.frameMs(), 20);
  EXPECT_EQ(config.bitrateBps, 24000);
  EXPECT_TRUE(config.fecEnabled);
  EXPECT_EQ(config.expectedLossPct, 10);
  EXPECT_TRUE(config.dtxEnabled);
  EXPECT_EQ(config.jitterMinMs, 20);
  EXPECT_EQ(config.jitterInitialMs, 40);
  EXPECT_EQ(config.jitterMaxMs, 120);
  EXPECT_EQ(config.controlPort, 47800);
  EXPECT_EQ(config.audioPort, 47801);
  EXPECT_EQ(config.vadTailMs, 300);
  EXPECT_EQ(config.keepaliveIntervalMs, 1000);
  EXPECT_EQ(config.controlPingIntervalMs, 1000);
  EXPECT_EQ(config.peerTimeoutMs, 5000);
  EXPECT_EQ(config.controlTimeoutMs, 5000);
  EXPECT_EQ(config.maxParticipants, 8);
  EXPECT_FALSE(config.echoMode);
}

TEST(CoreConfigTest, ConvertsMillisecondsToSamples) {
  const CoreConfig config;

  EXPECT_EQ(config.msToSamples(20), 320);
  EXPECT_EQ(config.msToSamples(10), 160);
}

TEST(CoreConfigTest, AcceptsValidClientAndHost) {
  EXPECT_EQ(validate(validClient()), ConfigError::kNone);
  EXPECT_EQ(validate(validHost()), ConfigError::kNone);
}

TEST(CoreConfigTest, TheHostIgnoresHostIp) {
  CoreConfig host = validHost();
  host.hostIp = "not an address";
  host.echoMode = true;

  EXPECT_EQ(validate(host), ConfigError::kNone);
}

TEST(CoreConfigTest, AcceptsEverySupportedFrameDuration) {
  for (const int samples : {160, 320, 640, 960}) {
    CoreConfig config = validClient();
    config.frameSamples = samples;
    config.jitterMinMs = 60;
    config.jitterInitialMs = 60;
    config.jitterMaxMs = 120;
    config.jitterAdaptHoldMs = 500;
    config.devicePeriodMs = 10;
    EXPECT_EQ(validate(config), ConfigError::kNone) << samples;
  }
}

TEST(CoreConfigTest, CountsDisplayNameCharactersNotBytes) {
  CoreConfig config = validClient();
  config.displayName = "Jo\xC3\xA3o";  // "João": 4 characters, 5 bytes
  EXPECT_EQ(validate(config), ConfigError::kNone);

  std::string name;
  for (int i = 0; i < 32; ++i) {
    name += "\xC3\xA9";  // 32 x "é" = 64 bytes
  }
  config.displayName = name;
  EXPECT_EQ(validate(config), ConfigError::kNone);
  config.displayName = name + "a";
  EXPECT_EQ(validate(config), ConfigError::kDisplayName);
}

struct InvalidCase {
  const char* name;
  std::function<void(CoreConfig&)> mutate;
  ConfigError expected;
};

class CoreConfigInvalidTest : public ::testing::TestWithParam<InvalidCase> {};

TEST_P(CoreConfigInvalidTest, RejectsTheField) {
  CoreConfig config = validClient();
  GetParam().mutate(config);

  EXPECT_EQ(validate(config), GetParam().expected);
}

INSTANTIATE_TEST_SUITE_P(
    EveryField, CoreConfigInvalidTest,
    ::testing::Values(
        InvalidCase{"EmptyHostIp", [](CoreConfig& c) { c.hostIp = ""; }, ConfigError::kHostIp},
        InvalidCase{"BadHostIp", [](CoreConfig& c) { c.hostIp = "192.168.1"; }, ConfigError::kHostIp},
        InvalidCase{"BroadcastHost", [](CoreConfig& c) { c.hostIp = "255.255.255.255"; },
                    ConfigError::kHostIp},
        InvalidCase{"MulticastHost", [](CoreConfig& c) { c.hostIp = "239.1.2.3"; },
                    ConfigError::kHostIp},
        InvalidCase{"EchoOnClient", [](CoreConfig& c) { c.echoMode = true; },
                    ConfigError::kEchoModeOnClient},
        InvalidCase{"EmptyName", [](CoreConfig& c) { c.displayName = ""; },
                    ConfigError::kDisplayName},
        InvalidCase{"LongName", [](CoreConfig& c) { c.displayName = std::string(33, 'a'); },
                    ConfigError::kDisplayName},
        InvalidCase{"PrivilegedControlPort", [](CoreConfig& c) { c.controlPort = 80; },
                    ConfigError::kControlPort},
        InvalidCase{"PrivilegedAudioPort", [](CoreConfig& c) { c.audioPort = 1023; },
                    ConfigError::kAudioPort},
        InvalidCase{"NegativeDscp", [](CoreConfig& c) { c.audioDscp = -1; }, ConfigError::kAudioDscp},
        InvalidCase{"LargeDscp", [](CoreConfig& c) { c.audioDscp = 64; }, ConfigError::kAudioDscp},
        InvalidCase{"SampleRate", [](CoreConfig& c) { c.sampleRateHz = 48000; },
                    ConfigError::kSampleRate},
        InvalidCase{"ZeroFrame", [](CoreConfig& c) { c.frameSamples = 0; },
                    ConfigError::kFrameSamples},
        InvalidCase{"HugeFrame", [](CoreConfig& c) { c.frameSamples = 2000000; },
                    ConfigError::kFrameSamples},
        InvalidCase{"FractionalFrame", [](CoreConfig& c) { c.frameSamples = 321; },
                    ConfigError::kFrameSamples},
        InvalidCase{"UnsupportedFrame", [](CoreConfig& c) { c.frameSamples = 480; },
                    ConfigError::kFrameSamples},
        InvalidCase{"LowBitrate", [](CoreConfig& c) { c.bitrateBps = 5999; }, ConfigError::kBitrate},
        InvalidCase{"HighBitrate", [](CoreConfig& c) { c.bitrateBps = 510001; },
                    ConfigError::kBitrate},
        InvalidCase{"NegativeLoss", [](CoreConfig& c) { c.expectedLossPct = -1; },
                    ConfigError::kExpectedLoss},
        InvalidCase{"LossAbove100", [](CoreConfig& c) { c.expectedLossPct = 101; },
                    ConfigError::kExpectedLoss},
        InvalidCase{"Complexity", [](CoreConfig& c) { c.opusComplexity = 11; },
                    ConfigError::kOpusComplexity},
        InvalidCase{"NegativeComplexity", [](CoreConfig& c) { c.opusComplexity = -1; },
                    ConfigError::kOpusComplexity},
        InvalidCase{"JitterMinBelowFrame", [](CoreConfig& c) { c.jitterMinMs = 10; },
                    ConfigError::kJitterRange},
        InvalidCase{"JitterInitialBelowMin", [](CoreConfig& c) { c.jitterInitialMs = 19; },
                    ConfigError::kJitterRange},
        InvalidCase{"JitterMaxBelowInitial", [](CoreConfig& c) { c.jitterMaxMs = 39; },
                    ConfigError::kJitterRange},
        InvalidCase{"JitterMaxTooLarge",
                    [](CoreConfig& c) { c.jitterMaxMs = 1001; }, ConfigError::kJitterRange},
        InvalidCase{"AdaptHoldBelowFrame", [](CoreConfig& c) { c.jitterAdaptHoldMs = 19; },
                    ConfigError::kJitterAdaptation},
        InvalidCase{"AdaptHoldTooLong", [](CoreConfig& c) { c.jitterAdaptHoldMs = 10001; },
                    ConfigError::kJitterAdaptation},
        InvalidCase{"ShortWindow", [](CoreConfig& c) { c.jitterWindowMs = 999; },
                    ConfigError::kJitterAdaptation},
        InvalidCase{"LongWindow", [](CoreConfig& c) { c.jitterWindowMs = 60001; },
                    ConfigError::kJitterAdaptation},
        InvalidCase{"NegativeConcealment", [](CoreConfig& c) { c.concealmentMaxMs = -1; },
                    ConfigError::kConcealment},
        InvalidCase{"LongConcealment", [](CoreConfig& c) { c.concealmentMaxMs = 1001; },
                    ConfigError::kConcealment},
        InvalidCase{"ZeroDevicePeriod", [](CoreConfig& c) { c.devicePeriodMs = 0; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"DevicePeriodAboveFrame", [](CoreConfig& c) { c.devicePeriodMs = 21; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"PlayoutBelowPeriod", [](CoreConfig& c) { c.playoutBufferMs = 9; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"PlayoutTooLarge", [](CoreConfig& c) { c.playoutBufferMs = 201; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"ZeroMediaPeriod", [](CoreConfig& c) { c.mediaLoopPeriodMs = 0; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"MediaPeriodAboveDevice", [](CoreConfig& c) { c.mediaLoopPeriodMs = 11; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"ZeroNetworkPoll", [](CoreConfig& c) { c.networkPollMs = 0; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"LongNetworkPoll", [](CoreConfig& c) { c.networkPollMs = 101; },
                    ConfigError::kDeviceTiming},
        InvalidCase{"FastKeepalive", [](CoreConfig& c) { c.keepaliveIntervalMs = 99; },
                    ConfigError::kKeepalive},
        InvalidCase{"SlowKeepalive", [](CoreConfig& c) { c.keepaliveIntervalMs = 10001; },
                    ConfigError::kKeepalive},
        InvalidCase{"TimeoutNotAboveKeepalive", [](CoreConfig& c) { c.peerTimeoutMs = 1000; },
                    ConfigError::kPeerTimeout},
        InvalidCase{"TimeoutTooLong", [](CoreConfig& c) { c.peerTimeoutMs = 60001; },
                    ConfigError::kPeerTimeout},
        InvalidCase{"FastStats", [](CoreConfig& c) { c.statsIntervalMs = 99; },
                    ConfigError::kStatsInterval},
        InvalidCase{"SlowStats", [](CoreConfig& c) { c.statsIntervalMs = 10001; },
                    ConfigError::kStatsInterval},
        InvalidCase{"FastControlPing", [](CoreConfig& c) { c.controlPingIntervalMs = 99; },
                    ConfigError::kControlTiming},
        InvalidCase{"ControlTimeoutNotAbovePing", [](CoreConfig& c) { c.controlTimeoutMs = 1000; },
                    ConfigError::kControlTiming},
        InvalidCase{"NegativeGrace", [](CoreConfig& c) { c.reconnectGraceMs = -1; },
                    ConfigError::kReconnectGrace},
        InvalidCase{"LongGrace", [](CoreConfig& c) { c.reconnectGraceMs = 600001; },
                    ConfigError::kReconnectGrace},
        InvalidCase{"OneParticipant", [](CoreConfig& c) { c.maxParticipants = 1; },
                    ConfigError::kMaxParticipants},
        InvalidCase{"NineParticipants", [](CoreConfig& c) { c.maxParticipants = 9; },
                    ConfigError::kMaxParticipants},
        InvalidCase{"NegativeVadTail", [](CoreConfig& c) { c.vadTailMs = -1; },
                    ConfigError::kVadTail},
        InvalidCase{"LongVadTail", [](CoreConfig& c) { c.vadTailMs = 2001; },
                    ConfigError::kVadTail}),
    [](const ::testing::TestParamInfo<InvalidCase>& paramInfo) {
      return std::string(paramInfo.param.name);
    });

}  // namespace
}  // namespace voice_core
