#include "dsp/webrtc_voice_detector.h"

#include <gtest/gtest.h>

#include <cstddef>
#include <vector>

#include "support/signals.h"

namespace voice_core {
namespace {

using testing::harmonicTone;
using testing::NoiseSource;

constexpr std::size_t kFrame = 320;

// Frames judged voiced out of `frames` consecutive harmonic-tone frames.
int voicedFrames(IVoiceDetector& detector, std::size_t frameSamples, int frames) {
  int voiced = 0;
  for (int i = 0; i < frames; ++i) {
    const std::vector<int16_t> frame =
        harmonicTone(frameSamples, static_cast<std::size_t>(i) * frameSamples, 200.0, 5000.0);
    voiced += detector.isVoice(frame.data()) ? 1 : 0;
  }
  return voiced;
}

TEST(WebRtcVoiceDetectorTest, HearsNoVoiceInSilence) {
  auto detector = WebRtcVoiceDetector::create(CoreConfig{}).value();
  const std::vector<int16_t> silence(kFrame, 0);

  EXPECT_FALSE(detector->isVoice(silence.data()));
}

TEST(WebRtcVoiceDetectorTest, HearsAVoicedSound) {
  auto detector = WebRtcVoiceDetector::create(CoreConfig{}).value();

  EXPECT_GT(voicedFrames(*detector, kFrame, 25), 20);
}

TEST(WebRtcVoiceDetectorTest, ReturnsToSilenceAfterItsHangover) {
  auto detector = WebRtcVoiceDetector::create(CoreConfig{}).value();
  voicedFrames(*detector, kFrame, 25);
  const std::vector<int16_t> silence(kFrame, 0);

  bool voice = true;
  for (int i = 0; i < 25; ++i) {
    voice = detector->isVoice(silence.data());
  }

  EXPECT_FALSE(voice);
}

TEST(WebRtcVoiceDetectorTest, JudgesEverySupportedFrameDuration) {
  for (const int frameMs : {10, 20, 40, 60}) {
    CoreConfig config;
    config.frameSamples = config.msToSamples(frameMs);
    auto detector = WebRtcVoiceDetector::create(config).value();

    EXPECT_GT(voicedFrames(*detector, static_cast<std::size_t>(config.frameSamples), 25), 15)
        << frameMs;
  }
}

TEST(WebRtcVoiceDetectorTest, StartsWithTheConfiguredSensitivity) {
  CoreConfig config;
  config.vadSensitivity = VadSensitivity::kHigh;

  EXPECT_EQ(WebRtcVoiceDetector::create(config).value()->sensitivity(), VadSensitivity::kHigh);
}

TEST(WebRtcVoiceDetectorTest, AHigherSensitivityOpensOnMoreNoise) {
  const auto voicedNoise = [](VadSensitivity sensitivity) {
    auto detector = WebRtcVoiceDetector::create(CoreConfig{}).value();
    detector->setSensitivity(sensitivity);
    NoiseSource noise(1200.0, 11);
    int voiced = 0;
    for (int i = 0; i < 100; ++i) {
      const std::vector<int16_t> frame = noise.next(kFrame);
      voiced += detector->isVoice(frame.data()) ? 1 : 0;
    }
    return voiced;
  };

  const int low = voicedNoise(VadSensitivity::kLow);
  const int medium = voicedNoise(VadSensitivity::kMedium);
  const int high = voicedNoise(VadSensitivity::kHigh);

  EXPECT_LE(low, medium);
  EXPECT_LE(medium, high);
  EXPECT_LT(low, high);
}

TEST(WebRtcVoiceDetectorTest, ChangesTheSensitivityOnlyWhenItDiffers) {
  auto detector = WebRtcVoiceDetector::create(CoreConfig{}).value();

  detector->setSensitivity(VadSensitivity::kMedium);
  EXPECT_EQ(detector->sensitivity(), VadSensitivity::kMedium);
  detector->setSensitivity(VadSensitivity::kLow);
  EXPECT_EQ(detector->sensitivity(), VadSensitivity::kLow);
}

}  // namespace
}  // namespace voice_core
