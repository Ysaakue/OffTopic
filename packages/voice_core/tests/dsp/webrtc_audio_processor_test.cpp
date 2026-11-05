// The WebRTC processing stages on synthetic signals: each stage is checked by
// its effect on energy after the adaptive parts have converged.

#include "dsp/webrtc_audio_processor.h"

#include <gtest/gtest.h>

#include <cstddef>
#include <deque>
#include <vector>

#include "support/signals.h"

namespace voice_core {
namespace {

using testing::energy;
using testing::harmonicTone;
using testing::NoiseSource;

constexpr std::size_t kFrame = 320;
constexpr int kFramesPerSecond = 50;

CoreConfig onlyNoiseSuppression(NoiseSuppression level) {
  CoreConfig config;
  config.noiseSuppression = level;
  config.automaticGain = false;
  config.highPassFilter = false;
  config.echoCancellation = false;
  return config;
}

// Output / input energy over the last second of `seconds` of white noise.
double noiseEnergyRatio(const CoreConfig& config, int seconds) {
  auto processor = WebRtcAudioProcessor::create(config).value();
  NoiseSource noise(1500.0, 7);
  double in = 0.0;
  double out = 0.0;
  const int frames = seconds * kFramesPerSecond;
  for (int i = 0; i < frames; ++i) {
    std::vector<int16_t> frame = noise.next(kFrame);
    const double before = energy(frame);
    processor->processCapture(frame.data());
    if (i >= frames - kFramesPerSecond) {
      in += before;
      out += energy(frame);
    }
  }
  EXPECT_EQ(processor->errors(), 0U);
  return out / in;
}

TEST(WebRtcAudioProcessorTest, SuppressesStationaryNoise) {
  EXPECT_LT(noiseEnergyRatio(onlyNoiseSuppression(NoiseSuppression::kHigh), 3), 0.25);
}

TEST(WebRtcAudioProcessorTest, StrongerLevelsSuppressMore) {
  const double low = noiseEnergyRatio(onlyNoiseSuppression(NoiseSuppression::kLow), 3);
  const double moderate = noiseEnergyRatio(onlyNoiseSuppression(NoiseSuppression::kModerate), 3);
  const double veryHigh = noiseEnergyRatio(onlyNoiseSuppression(NoiseSuppression::kVeryHigh), 3);

  EXPECT_LT(low, 0.8);
  EXPECT_LT(moderate, low);
  EXPECT_LT(veryHigh, moderate);
}

TEST(WebRtcAudioProcessorTest, LeavesNoiseAloneWithEveryStageOff) {
  CoreConfig config = onlyNoiseSuppression(NoiseSuppression::kOff);

  EXPECT_NEAR(noiseEnergyRatio(config, 1), 1.0, 0.01);
}

TEST(WebRtcAudioProcessorTest, TheAutomaticGainRaisesAQuietVoice) {
  CoreConfig config = onlyNoiseSuppression(NoiseSuppression::kOff);
  config.automaticGain = true;
  auto processor = WebRtcAudioProcessor::create(config).value();
  double in = 0.0;
  double out = 0.0;
  for (int i = 0; i < 2 * kFramesPerSecond; ++i) {
    std::vector<int16_t> frame = harmonicTone(kFrame, static_cast<std::size_t>(i) * kFrame, 180.0, 300.0);
    const double before = energy(frame);
    processor->processCapture(frame.data());
    if (i >= kFramesPerSecond) {
      in += before;
      out += energy(frame);
    }
  }

  EXPECT_GT(out, in * 2.0);
}

TEST(WebRtcAudioProcessorTest, TheHighPassFilterRemovesRumble) {
  CoreConfig config = onlyNoiseSuppression(NoiseSuppression::kOff);
  config.highPassFilter = true;
  auto processor = WebRtcAudioProcessor::create(config).value();
  double in = 0.0;
  double out = 0.0;
  for (int i = 0; i < kFramesPerSecond; ++i) {
    // 30 Hz: engine rumble, well below the filter's corner.
    std::vector<int16_t> frame(kFrame);
    for (std::size_t s = 0; s < kFrame; ++s) {
      const double t = static_cast<double>(static_cast<std::size_t>(i) * kFrame + s) /
                       testing::kTestRateHz;
      frame[s] = static_cast<int16_t>(std::lround(8000.0 * std::sin(2.0 * testing::kPi * 30.0 * t)));
    }
    const double before = energy(frame);
    processor->processCapture(frame.data());
    if (i >= kFramesPerSecond / 2) {
      in += before;
      out += energy(frame);
    }
  }

  EXPECT_LT(out, in * 0.5);
}

TEST(WebRtcAudioProcessorTest, TheEchoCancellerRemovesThePlayedSignal) {
  CoreConfig config = onlyNoiseSuppression(NoiseSuppression::kOff);
  config.echoCancellation = true;
  auto processor = WebRtcAudioProcessor::create(config).value();
  NoiseSource far(3000.0, 3);
  constexpr std::size_t kEchoDelayFrames = 2;  // 40 ms from speaker to microphone
  std::deque<std::vector<int16_t>> inFlight;
  double echo = 0.0;
  double residual = 0.0;
  const int frames = 6 * kFramesPerSecond;
  for (int i = 0; i < frames; ++i) {
    const std::vector<int16_t> render = far.next(kFrame);
    processor->analyzeRender(render.data());
    inFlight.push_back(render);
    std::vector<int16_t> capture(kFrame, 0);
    if (inFlight.size() > kEchoDelayFrames) {
      for (std::size_t s = 0; s < kFrame; ++s) {
        capture[s] = static_cast<int16_t>(inFlight.front()[s] / 2);
      }
      inFlight.pop_front();
    }
    const double before = energy(capture);
    processor->processCapture(capture.data());
    if (i >= frames - kFramesPerSecond) {
      echo += before;
      residual += energy(capture);
    }
  }

  EXPECT_LT(residual, echo * 0.1);
  EXPECT_EQ(processor->errors(), 0U);
}

}  // namespace
}  // namespace voice_core
