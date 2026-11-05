#include "engine/capture_chain.h"

namespace voice_core {

bool CaptureChain::processCapture(int16_t* frame) {
  processor_.processCapture(frame);
  const bool voice = gate_.needsVoiceDetection() && detector_.isVoice(frame);
  const bool send = gate_.update(voice);
  if (send != talking_) {
    talking_ = send;
    events_.emit(TalkingChangedEvent{send});
  }
  return send;
}

}  // namespace voice_core
