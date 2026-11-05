// The C API end to end, over an engine built from fakes (resetEngineForTesting).

#include "voice_core.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <limits>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "api/engine_registry.h"
#include "core_version.h"
#include "fakes/fake_audio_device.h"
#include "fakes/fake_network.h"
#include "fakes/fake_voice_processing.h"
#include "support/allocation_guard.h"

namespace {

using ::testing::ElementsAre;
using ::testing::MatchesRegex;
using voice_core::testing::AllocationGuard;

std::mutex eventsMutex;
std::vector<std::string> eventPayloads;

void collectEvent(int32_t /*event*/, char* payload) {
  {
    const std::lock_guard<std::mutex> lock(eventsMutex);
    eventPayloads.emplace_back(payload);
  }
  vc_free_event_payload(payload);
}

class VcApiTest : public ::testing::Test {
 protected:
  void SetUp() override {
    const voice_core::EngineDependencies dependencies{audio_, sockets_, clock_, processing_};
    voice_core::api::resetEngineForTesting(&dependencies);
    const std::lock_guard<std::mutex> lock(eventsMutex);
    eventPayloads.clear();
  }

  void TearDown() override { voice_core::api::resetEngineForTesting(nullptr); }

  static vc_config client() {
    vc_config config;
    vc_config_defaults(&config);
    config.host_ip = "127.0.0.1";
    config.display_name = "Ana";
    return config;
  }

  voice_core::testing::FakeNetwork network_{0x7F000001};
  voice_core::testing::FakeSocketFactory sockets_{network_};
  voice_core::testing::FakeAudioDeviceFactory audio_;
  voice_core::SteadyClock clock_;
  voice_core::testing::FakeVoiceProcessingFactory processing_;
};

TEST(VcVersionTest, ReturnsCoreVersion) { EXPECT_STREQ(vc_version(), voice_core::kVersion); }

TEST(VcVersionTest, IsSemanticVersion) {
  EXPECT_THAT(std::string(vc_version()), MatchesRegex("[0-9]+\\.[0-9]+\\.[0-9]+"));
}

TEST(VcVersionTest, ReturnsTheSameStaticStringOnEveryCall) {
  EXPECT_EQ(vc_version(), vc_version());
}

TEST(VcVersionTest, DoesNotAllocate) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const char* version = vc_version();

  EXPECT_NE(version, nullptr);
  EXPECT_EQ(guard.allocations(), 0U);
}

TEST_F(VcApiTest, RejectsNullPointers) {
  vc_config_defaults(nullptr);

  EXPECT_EQ(vc_init(nullptr), VC_ERR_INVALID_ARGUMENT);
  EXPECT_EQ(vc_get_stats(nullptr), VC_ERR_INVALID_ARGUMENT);
  vc_free_event_payload(nullptr);
}

TEST_F(VcApiTest, RejectsAnInvalidConfiguration) {
  vc_config config = client();
  config.host_ip = "999.1.1.1";

  EXPECT_EQ(vc_init(&config), VC_ERR_INVALID_ARGUMENT);
}

TEST_F(VcApiTest, RefusesToStartBeforeInit) { EXPECT_EQ(vc_start(), VC_ERR_INVALID_STATE); }

TEST_F(VcApiTest, RunsAFullLifecycle) {
  vc_set_event_callback(collectEvent);
  const vc_config config = client();

  ASSERT_EQ(vc_init(&config), VC_OK);
  ASSERT_EQ(vc_start(), VC_OK);
  EXPECT_EQ(vc_start(), VC_ERR_INVALID_STATE);
  vc_set_mute(1);
  vc_set_mute(0);
  vc_stop();
  vc_stop();
  vc_set_event_callback(nullptr);

  const std::lock_guard<std::mutex> lock(eventsMutex);
  EXPECT_THAT(eventPayloads, ElementsAre(R"({"state":"running"})", R"({"state":"stopped"})"));
}

TEST_F(VcApiTest, ReportsAFailedStartAsAnEvent) {
  sockets_.fail(true);
  vc_set_event_callback(collectEvent);
  const vc_config config = client();
  ASSERT_EQ(vc_init(&config), VC_OK);

  EXPECT_EQ(vc_start(), VC_ERR_NETWORK);
  vc_set_event_callback(nullptr);

  const std::lock_guard<std::mutex> lock(eventsMutex);
  EXPECT_THAT(eventPayloads, ElementsAre(R"({"state":"failed","error":-4})"));
}

TEST_F(VcApiTest, ReturnsZeroedStatisticsWhileIdle) {
  vc_stats stats;
  stats.packets_sent = 99;

  EXPECT_EQ(vc_get_stats(&stats), VC_ERR_INVALID_STATE);
  EXPECT_EQ(stats.packets_sent, 0U);
}

TEST_F(VcApiTest, ReturnsStatisticsWhileRunning) {
  const vc_config config = client();
  ASSERT_EQ(vc_init(&config), VC_OK);
  ASSERT_EQ(vc_start(), VC_OK);
  vc_stats stats{};

  EXPECT_EQ(vc_get_stats(&stats), VC_OK);
  EXPECT_GE(stats.jitter_target_ms, 0);
  vc_stop();
}

TEST_F(VcApiTest, AcceptsOnlyFiniteOutputGains) {
  vc_set_output_gain(std::numeric_limits<float>::quiet_NaN());
  vc_set_output_gain(std::numeric_limits<float>::infinity());
  vc_set_output_gain(-1.0F);
  vc_set_output_gain(100.0F);
  vc_set_output_gain(1.0F);
}

TEST_F(VcApiTest, DefaultsIncludeTheVoiceProcessing) {
  vc_config config;
  vc_config_defaults(&config);

  EXPECT_EQ(config.noise_suppression, VC_NOISE_SUPPRESSION_HIGH);
  EXPECT_EQ(config.automatic_gain, 1);
  EXPECT_EQ(config.echo_cancellation, 0);
  EXPECT_EQ(config.talk_mode, VC_TALK_MODE_VOICE);
  EXPECT_EQ(config.vad_sensitivity, VC_VAD_SENSITIVITY_MEDIUM);
  EXPECT_EQ(config.vad_tail_ms, 300);
}

TEST_F(VcApiTest, RejectsUnknownVoiceProcessingValues) {
  const auto rejected = [](void (*edit)(vc_config&)) {
    vc_config config = client();
    edit(config);
    return vc_init(&config) == VC_ERR_INVALID_ARGUMENT;
  };

  EXPECT_TRUE(rejected([](vc_config& c) { c.noise_suppression = 5; }));
  EXPECT_TRUE(rejected([](vc_config& c) { c.noise_suppression = 260; }));  // no wrap to 4
  EXPECT_TRUE(rejected([](vc_config& c) { c.talk_mode = -1; }));
  EXPECT_TRUE(rejected([](vc_config& c) { c.vad_sensitivity = 3; }));
  EXPECT_TRUE(rejected([](vc_config& c) { c.vad_tail_ms = -20; }));
}

TEST_F(VcApiTest, ValidatesTheVoiceControls) {
  EXPECT_EQ(vc_set_talk_mode(VC_TALK_MODE_PUSH_TO_TALK), VC_OK);
  EXPECT_EQ(vc_set_talk_mode(VC_TALK_MODE_VOICE), VC_OK);
  EXPECT_EQ(vc_set_talk_mode(2), VC_ERR_INVALID_ARGUMENT);
  EXPECT_EQ(vc_set_vad_sensitivity(VC_VAD_SENSITIVITY_LOW), VC_OK);
  EXPECT_EQ(vc_set_vad_sensitivity(-1), VC_ERR_INVALID_ARGUMENT);
  vc_set_push_to_talk(1);
  vc_set_push_to_talk(0);
}

TEST_F(VcApiTest, ReportsWhenTheMicrophoneIsSent) {
  vc_set_event_callback(collectEvent);
  const vc_config config = client();
  ASSERT_EQ(vc_init(&config), VC_OK);
  ASSERT_EQ(vc_start(), VC_OK);

  const auto talking = [] {
    const std::lock_guard<std::mutex> lock(eventsMutex);
    return std::find(eventPayloads.begin(), eventPayloads.end(), R"({"talking":true})") !=
           eventPayloads.end();
  };
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (!talking() && std::chrono::steady_clock::now() < deadline) {
    audio_.last->pump(std::vector<int16_t>(160, 1000));
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
  }
  vc_stop();
  vc_set_event_callback(nullptr);

  EXPECT_TRUE(talking());
}

// Under ThreadSanitizer: Kotlin drives the lifecycle while Dart polls.
TEST_F(VcApiTest, IsThreadSafe) {
  const vc_config config = client();
  ASSERT_EQ(vc_init(&config), VC_OK);
  std::atomic<bool> done{false};
  std::thread poller([&done] {
    vc_stats stats{};
    while (!done) {
      vc_get_stats(&stats);
      vc_set_output_gain(0.8F);
      vc_set_talk_mode(VC_TALK_MODE_PUSH_TO_TALK);
      vc_set_push_to_talk(1);
      vc_set_vad_sensitivity(VC_VAD_SENSITIVITY_HIGH);
      vc_set_talk_mode(VC_TALK_MODE_VOICE);
      vc_set_event_callback(collectEvent);
      vc_set_event_callback(nullptr);
    }
  });
  for (int i = 0; i < 20; ++i) {
    ASSERT_EQ(vc_start(), VC_OK);
    vc_set_mute(i % 2);
    vc_stop();
  }
  done = true;
  poller.join();
}

TEST_F(VcApiTest, UsesTheRealDependenciesByDefault) {
  voice_core::api::resetEngineForTesting(nullptr);
  vc_stats stats{};

  EXPECT_EQ(vc_get_stats(&stats), VC_ERR_INVALID_STATE);
}

}  // namespace
