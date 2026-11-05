#include "dsp/voice_processing_factory.h"

#include <gtest/gtest.h>

#include "dsp/webrtc_audio_processor.h"
#include "dsp/webrtc_voice_detector.h"

namespace voice_core {
namespace {

CoreConfig everyStageOff() {
  CoreConfig config;
  config.noiseSuppression = NoiseSuppression::kOff;
  config.automaticGain = false;
  config.highPassFilter = false;
  config.echoCancellation = false;
  return config;
}

TEST(VoiceProcessingFactoryTest, NeedsProcessingWhenAnyStageIsOn) {
  EXPECT_FALSE(needsAudioProcessing(everyStageOff()));
  EXPECT_TRUE(needsAudioProcessing(CoreConfig{}));

  CoreConfig noise = everyStageOff();
  noise.noiseSuppression = NoiseSuppression::kLow;
  CoreConfig gain = everyStageOff();
  gain.automaticGain = true;
  CoreConfig highPass = everyStageOff();
  highPass.highPassFilter = true;
  CoreConfig echo = everyStageOff();
  echo.echoCancellation = true;
  EXPECT_TRUE(needsAudioProcessing(noise));
  EXPECT_TRUE(needsAudioProcessing(gain));
  EXPECT_TRUE(needsAudioProcessing(highPass));
  EXPECT_TRUE(needsAudioProcessing(echo));
}

TEST(VoiceProcessingFactoryTest, BuildsTheWebRtcStages) {
  WebRtcVoiceProcessingFactory factory;

  Expected<VoiceProcessing> processing = factory.create(CoreConfig{});

  ASSERT_TRUE(processing.hasValue());
  EXPECT_NE(dynamic_cast<WebRtcAudioProcessor*>(processing.value().processor.get()), nullptr);
  EXPECT_NE(dynamic_cast<WebRtcVoiceDetector*>(processing.value().detector.get()), nullptr);
}

TEST(VoiceProcessingFactoryTest, SkipsTheApmWhenEveryStageIsOff) {
  WebRtcVoiceProcessingFactory factory;

  Expected<VoiceProcessing> processing = factory.create(everyStageOff());

  ASSERT_TRUE(processing.hasValue());
  EXPECT_NE(dynamic_cast<PassthroughAudioProcessor*>(processing.value().processor.get()), nullptr);
  EXPECT_NE(processing.value().detector, nullptr);  // the detector still drives the gate
}

}  // namespace
}  // namespace voice_core
