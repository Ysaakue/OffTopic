// Builds the microphone processing of a session: the audio processor and the
// voice detector. Injected into VoiceEngine so its tests can use scripted fakes
// instead of the WebRTC implementations.

#ifndef VOICE_CORE_SRC_DSP_VOICE_PROCESSING_FACTORY_H_
#define VOICE_CORE_SRC_DSP_VOICE_PROCESSING_FACTORY_H_

#include <memory>

#include "common/expected.h"
#include "config/core_config.h"
#include "dsp/audio_processor.h"
#include "dsp/voice_detector.h"

namespace voice_core {

struct VoiceProcessing {
  std::unique_ptr<IAudioProcessor> processor;
  std::unique_ptr<IVoiceDetector> detector;
};

class IVoiceProcessingFactory {
 public:
  virtual ~IVoiceProcessingFactory() = default;

  /// `config` must be valid.
  virtual Expected<VoiceProcessing> create(const CoreConfig& config) = 0;

 protected:
  IVoiceProcessingFactory() = default;
  IVoiceProcessingFactory(const IVoiceProcessingFactory&) = default;
  IVoiceProcessingFactory& operator=(const IVoiceProcessingFactory&) = default;
  IVoiceProcessingFactory(IVoiceProcessingFactory&&) = default;
  IVoiceProcessingFactory& operator=(IVoiceProcessingFactory&&) = default;
};

/// The WebRTC processor (or the passthrough one when every step is off) and
/// the WebRTC voice detector.
class WebRtcVoiceProcessingFactory final : public IVoiceProcessingFactory {
 public:
  Expected<VoiceProcessing> create(const CoreConfig& config) override;
};

/// Whether any processing step is on (otherwise the passthrough processor is used).
[[nodiscard]] bool needsAudioProcessing(const CoreConfig& config) noexcept;

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_VOICE_PROCESSING_FACTORY_H_
