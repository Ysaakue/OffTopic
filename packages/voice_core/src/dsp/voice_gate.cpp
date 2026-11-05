#include "dsp/voice_gate.h"

namespace voice_core {

// The tail is rounded up to whole frames (300 ms of 40 ms frames is 8 frames).
VoiceGate::VoiceGate(const CoreConfig& config) noexcept
    : tailFrames_((config.vadTailMs + config.frameMs() - 1) / config.frameMs()),
      mode_(config.talkMode) {}

bool VoiceGate::update(bool voice) noexcept {
  if (muted_) {
    tailLeft_ = 0;
    open_ = false;
  } else if (mode_ == TalkMode::kPushToTalk) {
    tailLeft_ = 0;
    open_ = pushToTalk_;
  } else if (voice) {
    tailLeft_ = tailFrames_;
    open_ = true;
  } else if (tailLeft_ > 0) {
    --tailLeft_;
    open_ = true;
  } else {
    open_ = false;
  }
  return open_;
}

}  // namespace voice_core
