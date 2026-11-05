#include "dsp/voice_gate.h"

#include <gtest/gtest.h>

namespace voice_core {
namespace {

constexpr int kTailFrames = 15;  // 300 ms of 20 ms frames (docs/SPEC.md)

TEST(VoiceGateTest, StartsClosed) {
  const VoiceGate gate{CoreConfig{}};

  EXPECT_FALSE(gate.open());
  EXPECT_TRUE(gate.needsVoiceDetection());
}

TEST(VoiceGateTest, OpensOnVoice) {
  VoiceGate gate{CoreConfig{}};

  EXPECT_FALSE(gate.update(false));
  EXPECT_TRUE(gate.update(true));
  EXPECT_TRUE(gate.open());
}

TEST(VoiceGateTest, KeepsExactlyTheTailAfterSpeechStops) {
  VoiceGate gate{CoreConfig{}};
  gate.update(true);

  for (int frame = 0; frame < kTailFrames; ++frame) {
    EXPECT_TRUE(gate.update(false)) << frame;
  }
  EXPECT_FALSE(gate.update(false));
}

TEST(VoiceGateTest, SpeechDuringTheTailRestartsIt) {
  VoiceGate gate{CoreConfig{}};
  gate.update(true);
  for (int frame = 0; frame < kTailFrames - 1; ++frame) {
    gate.update(false);
  }

  gate.update(true);

  for (int frame = 0; frame < kTailFrames; ++frame) {
    EXPECT_TRUE(gate.update(false)) << frame;
  }
  EXPECT_FALSE(gate.update(false));
}

TEST(VoiceGateTest, RoundsTheTailUpToWholeFrames) {
  CoreConfig config;
  config.frameSamples = config.msToSamples(40);  // 300 ms -> 8 frames of 40 ms
  VoiceGate gate{config};
  gate.update(true);

  for (int frame = 0; frame < 8; ++frame) {
    EXPECT_TRUE(gate.update(false)) << frame;
  }
  EXPECT_FALSE(gate.update(false));
}

TEST(VoiceGateTest, ANoTailGateClosesWithTheVoice) {
  CoreConfig config;
  config.vadTailMs = 0;
  VoiceGate gate{config};

  EXPECT_TRUE(gate.update(true));
  EXPECT_FALSE(gate.update(false));
}

TEST(VoiceGateTest, PushToTalkIgnoresTheDetector) {
  CoreConfig config;
  config.talkMode = TalkMode::kPushToTalk;
  VoiceGate gate{config};

  EXPECT_FALSE(gate.needsVoiceDetection());
  EXPECT_FALSE(gate.update(true));
  gate.setPushToTalk(true);
  EXPECT_TRUE(gate.update(false));
  gate.setPushToTalk(false);
  EXPECT_FALSE(gate.update(true));  // closes at once: no tail
}

TEST(VoiceGateTest, MuteWinsOverVoiceAndPushToTalk) {
  VoiceGate gate{CoreConfig{}};
  gate.setMuted(true);

  EXPECT_FALSE(gate.needsVoiceDetection());
  EXPECT_FALSE(gate.update(true));
  gate.setMode(TalkMode::kPushToTalk);
  gate.setPushToTalk(true);
  EXPECT_FALSE(gate.update(true));
}

TEST(VoiceGateTest, MutingDropsTheTail) {
  VoiceGate gate{CoreConfig{}};
  gate.update(true);
  gate.setMuted(true);
  gate.update(false);

  gate.setMuted(false);

  EXPECT_FALSE(gate.update(false));
}

TEST(VoiceGateTest, SwitchingToPushToTalkDropsTheTail) {
  VoiceGate gate{CoreConfig{}};
  gate.update(true);
  gate.setMode(TalkMode::kPushToTalk);
  gate.update(false);

  gate.setMode(TalkMode::kVoice);

  EXPECT_FALSE(gate.update(false));
  EXPECT_TRUE(gate.needsVoiceDetection());
}

}  // namespace
}  // namespace voice_core
