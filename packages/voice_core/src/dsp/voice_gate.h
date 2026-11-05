// Decides, frame by frame, whether the microphone is sent. Pure logic: the
// voice detector's verdict comes in, the decision goes out.
//
//   muted        -> closed, whatever else happens
//   push to talk -> open exactly while the button is held (the detector is ignored)
//   voice        -> open on speech and for vadTailMs after it (the tail keeps
//                   word endings and short pauses)

#ifndef VOICE_CORE_SRC_DSP_VOICE_GATE_H_
#define VOICE_CORE_SRC_DSP_VOICE_GATE_H_

#include "config/core_config.h"

namespace voice_core {

class VoiceGate {
 public:
  explicit VoiceGate(const CoreConfig& config) noexcept;

  void setMode(TalkMode mode) noexcept { mode_ = mode; }
  void setPushToTalk(bool pressed) noexcept { pushToTalk_ = pressed; }
  void setMuted(bool muted) noexcept { muted_ = muted; }

  /// Whether the next frame needs the voice detector's verdict at all.
  [[nodiscard]] bool needsVoiceDetection() const noexcept {
    return !muted_ && mode_ == TalkMode::kVoice;
  }

  /// Decides for one frame; `voice` is the detector's verdict (ignored unless
  /// needsVoiceDetection()). Returns whether the frame is sent.
  bool update(bool voice) noexcept;

  [[nodiscard]] bool open() const noexcept { return open_; }

 private:
  const int tailFrames_;
  TalkMode mode_;
  bool pushToTalk_ = false;
  bool muted_ = false;
  int tailLeft_ = 0;
  bool open_ = false;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_DSP_VOICE_GATE_H_
