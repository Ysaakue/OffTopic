#include "engine/capture_chain.h"

#include <gtest/gtest.h>

#include <vector>

#include "fakes/fake_voice_processing.h"
#include "fakes/recording_event_sink.h"

namespace voice_core {
namespace {

using testing::RecordingAudioProcessor;
using testing::RecordingEventSink;
using testing::ScriptedVoiceDetector;

class CaptureChainTest : public ::testing::Test {
 protected:
  bool capture() {
    std::vector<int16_t> frame(320, 100);
    const bool sent = chain_.processCapture(frame.data());
    lastFirstSample_ = frame[0];
    return sent;
  }

  CoreConfig config_;
  RecordingAudioProcessor processor_{7};
  ScriptedVoiceDetector detector_;
  VoiceGate gate_{config_};
  RecordingEventSink events_;
  CaptureChain chain_{processor_, detector_, gate_, events_};
  int16_t lastFirstSample_ = 0;
};

TEST_F(CaptureChainTest, ProcessesTheFrameInPlaceAndSendsVoice) {
  EXPECT_TRUE(capture());

  EXPECT_EQ(processor_.captured.load(), 1);
  EXPECT_EQ(lastFirstSample_, 107);  // the processor's mark
  EXPECT_EQ(detector_.calls.load(), 1);
}

TEST_F(CaptureChainTest, HoldsFramesWithoutVoice) {
  detector_.voice = false;

  EXPECT_FALSE(capture());
  EXPECT_TRUE(events_.talkingStates().empty());
}

TEST_F(CaptureChainTest, ReportsEachChangeOfTheGateOnce) {
  capture();
  capture();
  gate_.setMuted(true);
  capture();
  capture();

  EXPECT_EQ(events_.talkingStates(), (std::vector<bool>{true, false}));
}

TEST_F(CaptureChainTest, AsksTheDetectorOnlyWhenTheGateNeedsIt) {
  gate_.setMode(TalkMode::kPushToTalk);
  gate_.setPushToTalk(true);

  EXPECT_TRUE(capture());
  EXPECT_EQ(detector_.calls.load(), 0);
}

TEST_F(CaptureChainTest, ForwardsTheRenderReference) {
  const std::vector<int16_t> played(320, -42);

  chain_.analyzeRender(played.data());

  EXPECT_EQ(processor_.rendered.load(), 1);
  EXPECT_EQ(processor_.lastRenderSample.load(), -42);
}

}  // namespace
}  // namespace voice_core
