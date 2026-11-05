// VoiceEngine lifecycle with fake device and network. These tests start the
// real media and network threads (the engine is their owner), so the few
// end-to-end checks wait, with a bound, for the threads to make progress.

#include "engine/voice_engine.h"

#include <gtest/gtest.h>

#include <chrono>
#include <cmath>
#include <functional>
#include <thread>
#include <vector>

#include "fakes/fake_audio_device.h"
#include "fakes/fake_network.h"
#include "fakes/fake_voice_processing.h"

namespace voice_core {
namespace {

using testing::FakeAudioDeviceFactory;
using testing::FakeNetwork;
using testing::FakeSocketFactory;
using testing::FakeVoiceProcessingFactory;

constexpr uint32_t kLoopback = 0x7F000001;

bool eventually(const std::function<bool()>& condition) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (std::chrono::steady_clock::now() < deadline) {
    if (condition()) {
      return true;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
  }
  return condition();
}

std::vector<int16_t> sine(std::size_t samples) {
  std::vector<int16_t> out(samples);
  for (std::size_t i = 0; i < samples; ++i) {
    out[i] = static_cast<int16_t>(std::lround(9000.0 * std::sin(static_cast<double>(i) * 0.12)));
  }
  return out;
}

class VoiceEngineTest : public ::testing::Test {
 protected:
  static CoreConfig client() {
    CoreConfig config;
    config.hostIp = "127.0.0.1";
    config.displayName = "Ana";
    return config;
  }

  static CoreConfig host() {
    CoreConfig config;
    config.role = Role::kHost;
    config.displayName = "Bia";
    return config;
  }

  std::size_t audioSent() const {
    std::size_t count = 0;
    for (const testing::SentDatagram& sent : sockets_.last()->sent()) {
      count += (sent.bytes[0] & 0x01U) == 0 ? 1U : 0U;
    }
    return count;
  }

  FakeNetwork network_{kLoopback};
  FakeSocketFactory sockets_{network_};
  FakeAudioDeviceFactory audio_;
  SteadyClock clock_;
  FakeVoiceProcessingFactory processing_;
  VoiceEngine engine_{EngineDependencies{audio_, sockets_, clock_, processing_}};
};

TEST_F(VoiceEngineTest, RefusesToStartWithoutInit) {
  EXPECT_EQ(engine_.start(), Status::kInvalidState);
  EXPECT_FALSE(engine_.running());
}

TEST_F(VoiceEngineTest, RejectsAnInvalidConfiguration) {
  CoreConfig config = client();
  config.hostIp = "nope";

  EXPECT_EQ(engine_.init(config), Status::kInvalidArgument);
  EXPECT_EQ(engine_.start(), Status::kInvalidState);
}

TEST_F(VoiceEngineTest, StartsAndStops) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);

  ASSERT_EQ(engine_.start(), Status::kOk);
  EXPECT_TRUE(engine_.running());
  ASSERT_NE(audio_.last, nullptr);
  EXPECT_TRUE(audio_.last->started());
  EXPECT_EQ(audio_.lastParams.sampleRateHz, 16000);
  EXPECT_EQ(audio_.lastParams.periodFrames, 160);
  EXPECT_EQ(sockets_.lastOptions().port, 0);  // the client uses an ephemeral port
  EXPECT_EQ(sockets_.lastOptions().dscp, 46);

  engine_.stop();
  EXPECT_FALSE(engine_.running());
  EXPECT_EQ(audio_.stops.load(), 1);
}

TEST_F(VoiceEngineTest, TheHostListensOnTheAudioPort) {
  ASSERT_EQ(engine_.init(host()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  EXPECT_EQ(sockets_.lastOptions().port, 47801);
}

TEST_F(VoiceEngineTest, RefusesToStartOrReconfigureWhileRunning) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  EXPECT_EQ(engine_.start(), Status::kInvalidState);
  EXPECT_EQ(engine_.init(client()), Status::kInvalidState);
}

TEST_F(VoiceEngineTest, StopIsIdempotent) {
  engine_.stop();
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  engine_.stop();
  engine_.stop();

  EXPECT_EQ(audio_.stops.load(), 1);
}

TEST_F(VoiceEngineTest, CanStartAgainAfterStopping) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  engine_.stop();

  EXPECT_EQ(engine_.start(), Status::kOk);
  EXPECT_EQ(audio_.created, 2);
}

TEST_F(VoiceEngineTest, ReportsANetworkFailure) {
  sockets_.fail(true);
  ASSERT_EQ(engine_.init(client()), Status::kOk);

  EXPECT_EQ(engine_.start(), Status::kNetwork);
  EXPECT_FALSE(engine_.running());
  EXPECT_EQ(audio_.created, 0);
}

TEST_F(VoiceEngineTest, ReportsAnAudioDeviceFailure) {
  audio_.startStatus = Status::kAudioDevice;
  ASSERT_EQ(engine_.init(client()), Status::kOk);

  EXPECT_EQ(engine_.start(), Status::kAudioDevice);
  EXPECT_FALSE(engine_.running());
  EXPECT_EQ(audio_.created, 2);  // one retry, then it gives up
}

// A call route applied while the streams start disconnects them on Android.
TEST_F(VoiceEngineTest, RetriesTheAudioDeviceOnceWithAFreshOne) {
  audio_.startStatuses = {Status::kAudioDevice, Status::kOk};
  ASSERT_EQ(engine_.init(client()), Status::kOk);

  EXPECT_EQ(engine_.start(), Status::kOk);
  EXPECT_TRUE(engine_.running());
  EXPECT_EQ(audio_.created, 2);
  ASSERT_NE(audio_.last, nullptr);
  EXPECT_TRUE(audio_.last->started());
}

TEST_F(VoiceEngineTest, HasNoStatisticsWhileIdle) {
  EngineStats stats;
  stats.captureOverruns = 77;

  EXPECT_FALSE(engine_.readStats(&stats));
  EXPECT_EQ(stats.captureOverruns, 77U);
}

TEST_F(VoiceEngineTest, PublishesStatisticsWhileRunning) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  EXPECT_TRUE(eventually([this] {
    EngineStats stats;
    return engine_.readStats(&stats) && stats.session.jitterTargetMs == 40;
  }));
  // The media loop keeps playoutBufferMs (20 ms) of decoded audio queued.
  EXPECT_TRUE(eventually([this] {
    EngineStats stats;
    return engine_.readStats(&stats) && stats.playoutQueueMs >= 20;
  }));
}

TEST_F(VoiceEngineTest, SendsCapturedAudioEndToEnd) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  const std::vector<int16_t> samples = sine(320);

  for (int i = 0; i < 5; ++i) {
    audio_.last->pump(samples);
  }

  EXPECT_TRUE(eventually([this] { return audioSent() >= 5; }));
}

TEST_F(VoiceEngineTest, MuteStopsTheMicrophone) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  engine_.setMuted(true);
  engine_.setOutputGain(0.5F);
  // Any media iteration that read the old mute state (2 ms period) is over.
  std::this_thread::sleep_for(std::chrono::milliseconds(20));
  const std::vector<int16_t> samples = sine(320);

  for (int i = 0; i < 5; ++i) {
    audio_.last->pump(samples);
  }
  std::this_thread::sleep_for(std::chrono::milliseconds(50));

  EXPECT_EQ(audioSent(), 0U);
}

TEST_F(VoiceEngineTest, PlaysSilenceWhenNothingArrives) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  ASSERT_TRUE(eventually([this] {
    EngineStats stats;
    return engine_.readStats(&stats);
  }));

  std::vector<int16_t> played;
  ASSERT_TRUE(eventually([this, &played] {
    played = audio_.last->pump(std::vector<int16_t>(160, 0));
    return played[0] == 0;
  }));
  EXPECT_EQ(played.size(), 160U);
}

TEST_F(VoiceEngineTest, ReportsAVoiceProcessingFailure) {
  processing_.failWith = Status::kInternal;
  ASSERT_EQ(engine_.init(client()), Status::kOk);

  EXPECT_EQ(engine_.start(), Status::kInternal);
  EXPECT_FALSE(engine_.running());
  EXPECT_EQ(audio_.created, 0);
}

TEST_F(VoiceEngineTest, BuildsTheVoiceProcessingFromTheConfiguration) {
  CoreConfig config = client();
  config.vadSensitivity = VadSensitivity::kHigh;
  ASSERT_EQ(engine_.init(config), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  EXPECT_EQ(processing_.lastConfig.vadSensitivity, VadSensitivity::kHigh);
  EXPECT_TRUE(eventually([this] {
    return processing_.lastDetector->sensitivity.load() == VadSensitivity::kHigh;
  }));
}

TEST_F(VoiceEngineTest, ProcessesTheMicrophoneBeforeSendingIt) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  audio_.last->pump(sine(320));

  EXPECT_TRUE(eventually([this] { return processing_.lastProcessor->captured.load() == 1; }));
}

TEST_F(VoiceEngineTest, SendsNothingWhileTheDetectorHearsNoVoice) {
  processing_.voice = false;
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  for (int i = 0; i < 5; ++i) {
    audio_.last->pump(sine(320));
  }
  ASSERT_TRUE(eventually([this] { return processing_.lastProcessor->captured.load() == 5; }));

  EXPECT_EQ(audioSent(), 0U);
}

TEST_F(VoiceEngineTest, PushToTalkSendsOnlyWhileHeld) {
  CoreConfig config = client();
  config.talkMode = TalkMode::kPushToTalk;
  ASSERT_EQ(engine_.init(config), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);
  audio_.last->pump(sine(320));
  ASSERT_TRUE(eventually([this] { return processing_.lastProcessor->captured.load() == 1; }));
  EXPECT_EQ(audioSent(), 0U);

  engine_.setPushToTalk(true);
  ASSERT_TRUE(eventually([this] {
    audio_.last->pump(sine(320));
    return audioSent() > 0;
  }));
  EXPECT_EQ(processing_.lastDetector->calls.load(), 0);  // push to talk ignores the detector
}

TEST_F(VoiceEngineTest, SwitchesTheTalkModeWhileRunning) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  engine_.setTalkMode(TalkMode::kPushToTalk);
  // Any frame decided before the switch has been sent by now.
  std::this_thread::sleep_for(std::chrono::milliseconds(20));
  const std::size_t before = audioSent();
  for (int i = 1; i <= 5; ++i) {
    audio_.last->pump(sine(320));
    // One frame at a time: the capture ring holds only a few frames.
    ASSERT_TRUE(eventually([this, i] { return processing_.lastProcessor->captured.load() == i; }));
  }

  EXPECT_EQ(audioSent(), before);
}

TEST_F(VoiceEngineTest, AppliesTheVadSensitivityWhileRunning) {
  ASSERT_EQ(engine_.init(client()), Status::kOk);
  ASSERT_EQ(engine_.start(), Status::kOk);

  engine_.setVadSensitivity(VadSensitivity::kLow);

  EXPECT_TRUE(eventually([this] {
    return processing_.lastDetector->sensitivity.load() == VadSensitivity::kLow;
  }));
}

TEST_F(VoiceEngineTest, StopsARunningEngineOnDestruction) {
  {
    VoiceEngine engine(EngineDependencies{audio_, sockets_, clock_, processing_});
    ASSERT_EQ(engine.init(client()), Status::kOk);
    ASSERT_EQ(engine.start(), Status::kOk);
  }

  EXPECT_EQ(audio_.stops.load(), 1);
}

}  // namespace
}  // namespace voice_core
