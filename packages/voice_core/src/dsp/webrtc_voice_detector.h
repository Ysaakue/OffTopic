// IVoiceDetector over the WebRTC GMM voice activity detector (common_audio
// VAD). It judges 10 ms blocks; a frame is speech when any block is.

#ifndef VOICE_CORE_SRC_DSP_WEBRTC_VOICE_DETECTOR_H_
#define VOICE_CORE_SRC_DSP_WEBRTC_VOICE_DETECTOR_H_

#include <cstddef>
#include <cstdint>
#include <memory>

#include "common/expected.h"
#include "config/core_config.h"
#include "dsp/voice_detector.h"

struct WebRtcVadInst;

namespace voice_core {

class WebRtcVoiceDetector final : public IVoiceDetector {
 public:
  /// `config` must be valid. kInternal if the detector cannot be created.
  static Expected<std::unique_ptr<WebRtcVoiceDetector>> create(const CoreConfig& config);

  [[nodiscard]] bool isVoice(const int16_t* frame) noexcept override;
  void setSensitivity(VadSensitivity sensitivity) noexcept override;

  [[nodiscard]] VadSensitivity sensitivity() const noexcept { return sensitivity_; }

 private:
  struct Free {
    void operator()(WebRtcVadInst* vad) const noexcept;
  };

  WebRtcVoiceDetector(std::unique_ptr<WebRtcVadInst, Free> vad, const CoreConfig& config) noexcept;

  std::unique_ptr<WebRtcVadInst, Free> vad_;
  const int sampleRateHz_;
  const std::size_t frameSamples_;
  const std::size_t blockSamples_;
  VadSensitivity sensitivity_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_WEBRTC_VOICE_DETECTOR_H_
