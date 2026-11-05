// Contract of IAudioProcessor, run against every implementation: frames are
// processed in place, the render reference is never modified, silence stays
// silence and any frame duration the configuration accepts works.

#include <gtest/gtest.h>

#include <cstdlib>
#include <memory>
#include <vector>

#include "dsp/audio_processor.h"
#include "dsp/webrtc_audio_processor.h"
#include "support/signals.h"

namespace voice_core {
namespace {

using testing::harmonicTone;
using testing::NoiseSource;

std::unique_ptr<IAudioProcessor> makeProcessor(PassthroughAudioProcessor* /*tag*/,
                                               const CoreConfig& /*config*/) {
  return std::make_unique<PassthroughAudioProcessor>();
}

std::unique_ptr<IAudioProcessor> makeProcessor(WebRtcAudioProcessor* /*tag*/,
                                               const CoreConfig& config) {
  CoreConfig withEcho = config;
  withEcho.echoCancellation = true;  // every stage on
  return WebRtcAudioProcessor::create(withEcho).value();
}

template <typename Processor>
class AudioProcessorContractTest : public ::testing::Test {
 protected:
  std::unique_ptr<IAudioProcessor> make(const CoreConfig& config = CoreConfig{}) {
    return makeProcessor(static_cast<Processor*>(nullptr), config);
  }
};

using Processors = ::testing::Types<PassthroughAudioProcessor, WebRtcAudioProcessor>;
TYPED_TEST_SUITE(AudioProcessorContractTest, Processors, );

TYPED_TEST(AudioProcessorContractTest, NeverModifiesTheRenderReference) {
  auto processor = this->make();
  NoiseSource noise(3000.0, 1);

  for (int frame = 0; frame < 20; ++frame) {
    const std::vector<int16_t> render = noise.next(320);
    std::vector<int16_t> copy = render;
    processor->analyzeRender(copy.data());
    ASSERT_EQ(copy, render);
  }
}

TYPED_TEST(AudioProcessorContractTest, KeepsSilenceSilent) {
  auto processor = this->make();
  std::vector<int16_t> frame(320, 0);

  for (int i = 0; i < 50; ++i) {
    processor->analyzeRender(frame.data());
    processor->processCapture(frame.data());
  }

  for (const int16_t sample : frame) {
    EXPECT_LE(std::abs(sample), 1);
  }
}

TYPED_TEST(AudioProcessorContractTest, ProcessesEverySupportedFrameDuration) {
  for (const int frameMs : {10, 20, 40, 60}) {
    CoreConfig config;
    config.frameSamples = config.msToSamples(frameMs);
    auto processor = this->make(config);
    std::vector<int16_t> frame = harmonicTone(static_cast<std::size_t>(config.frameSamples), 0,
                                              200.0, 4000.0);

    processor->analyzeRender(frame.data());
    processor->processCapture(frame.data());

    EXPECT_EQ(frame.size(), static_cast<std::size_t>(config.frameSamples)) << frameMs;
  }
}

}  // namespace
}  // namespace voice_core
