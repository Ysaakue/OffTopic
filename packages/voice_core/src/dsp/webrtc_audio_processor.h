// IAudioProcessor over the WebRTC audio processing module (APM): high-pass
// filter, noise suppression, adaptive digital gain (AGC2) and the AEC3 echo
// canceller, as configured in CoreConfig. The APM works on 10 ms blocks, so
// each frame is processed as frameMs / 10 consecutive blocks.

#ifndef VOICE_CORE_SRC_DSP_WEBRTC_AUDIO_PROCESSOR_H_
#define VOICE_CORE_SRC_DSP_WEBRTC_AUDIO_PROCESSOR_H_

#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

#include "common/expected.h"
#include "config/core_config.h"
#include "dsp/audio_processor.h"

namespace voice_core {

class WebRtcAudioProcessor final : public IAudioProcessor {
 public:
  /// `config` must be valid. kInternal if the APM cannot be created.
  static Expected<std::unique_ptr<WebRtcAudioProcessor>> create(const CoreConfig& config);

  ~WebRtcAudioProcessor() override;
  WebRtcAudioProcessor(const WebRtcAudioProcessor&) = delete;
  WebRtcAudioProcessor& operator=(const WebRtcAudioProcessor&) = delete;
  WebRtcAudioProcessor(WebRtcAudioProcessor&&) = delete;
  WebRtcAudioProcessor& operator=(WebRtcAudioProcessor&&) = delete;

  void processCapture(int16_t* frame) noexcept override;
  void analyzeRender(const int16_t* frame) noexcept override;

  /// Blocks the APM refused (it then leaves them unprocessed).
  [[nodiscard]] uint32_t errors() const noexcept { return errors_; }

 private:
  struct Apm;

  WebRtcAudioProcessor(std::unique_ptr<Apm> apm, const CoreConfig& config) noexcept;

  std::unique_ptr<Apm> apm_;
  const std::size_t frameSamples_;
  const std::size_t blockSamples_;
  const bool echoCancellation_;
  std::vector<int16_t> renderScratch_;  // allocated once: processing never allocates
  uint32_t errors_ = 0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_WEBRTC_AUDIO_PROCESSOR_H_
