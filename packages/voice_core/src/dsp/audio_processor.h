// Voice processing of the microphone signal before it is encoded: noise
// suppression, automatic gain and, optionally, echo cancellation. Runs on the
// media thread (never in the audio callback), one frame at a time.

#ifndef VOICE_CORE_SRC_DSP_AUDIO_PROCESSOR_H_
#define VOICE_CORE_SRC_DSP_AUDIO_PROCESSOR_H_

#include <cstdint>

namespace voice_core {

class IAudioProcessor {
 public:
  virtual ~IAudioProcessor() = default;

  /// Cleans one captured frame (CoreConfig::frameSamples samples) in place.
  virtual void processCapture(int16_t* frame) noexcept = 0;

  /// One frame about to be played (frameSamples): the echo canceller's
  /// reference. Unchanged.
  virtual void analyzeRender(const int16_t* frame) noexcept = 0;

 protected:
  IAudioProcessor() = default;
  IAudioProcessor(const IAudioProcessor&) = default;
  IAudioProcessor& operator=(const IAudioProcessor&) = default;
  IAudioProcessor(IAudioProcessor&&) = default;
  IAudioProcessor& operator=(IAudioProcessor&&) = default;
};

/// Leaves the audio untouched: used when every processing step is off.
class PassthroughAudioProcessor final : public IAudioProcessor {
 public:
  void processCapture(int16_t* /*frame*/) noexcept override {}
  void analyzeRender(const int16_t* /*frame*/) noexcept override {}
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_AUDIO_PROCESSOR_H_
