// Decides whether a microphone frame contains speech (voice activity
// detection). Runs on the media thread after the audio processor.

#ifndef VOICE_CORE_SRC_DSP_VOICE_DETECTOR_H_
#define VOICE_CORE_SRC_DSP_VOICE_DETECTOR_H_

#include <cstdint>

#include "config/core_config.h"

namespace voice_core {

class IVoiceDetector {
 public:
  virtual ~IVoiceDetector() = default;

  /// Whether one frame (CoreConfig::frameSamples samples) contains speech.
  [[nodiscard]] virtual bool isVoice(const int16_t* frame) noexcept = 0;

  virtual void setSensitivity(VadSensitivity sensitivity) noexcept = 0;

 protected:
  IVoiceDetector() = default;
  IVoiceDetector(const IVoiceDetector&) = default;
  IVoiceDetector& operator=(const IVoiceDetector&) = default;
  IVoiceDetector(IVoiceDetector&&) = default;
  IVoiceDetector& operator=(IVoiceDetector&&) = default;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_VOICE_DETECTOR_H_
