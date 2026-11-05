#include "dsp/voice_processing_factory.h"

#include <utility>

#include "dsp/webrtc_audio_processor.h"
#include "dsp/webrtc_voice_detector.h"

namespace voice_core {

bool needsAudioProcessing(const CoreConfig& config) noexcept {
  return config.noiseSuppression != NoiseSuppression::kOff || config.automaticGain ||
         config.highPassFilter || config.echoCancellation;
}

Expected<VoiceProcessing> WebRtcVoiceProcessingFactory::create(const CoreConfig& config) {
  VoiceProcessing processing;
  if (needsAudioProcessing(config)) {
    Expected<std::unique_ptr<WebRtcAudioProcessor>> processor = WebRtcAudioProcessor::create(config);
    if (!processor) {              // GCOVR_EXCL_BR_LINE: allocation failure only
      return processor.status();  // GCOVR_EXCL_LINE: see above
    }
    processing.processor = std::move(processor).value();
  } else {
    processing.processor = std::make_unique<PassthroughAudioProcessor>();
  }
  Expected<std::unique_ptr<WebRtcVoiceDetector>> detector = WebRtcVoiceDetector::create(config);
  if (!detector) {              // GCOVR_EXCL_BR_LINE: allocation failure only
    return detector.status();  // GCOVR_EXCL_LINE: see above
  }
  processing.detector = std::move(detector).value();
  return processing;
}

}  // namespace voice_core
