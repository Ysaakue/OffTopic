// What happens to a captured frame before the session encodes it: voice
// processing, voice detection and the gate that decides whether it is sent.
// Reports every change of the gate as a TalkingChangedEvent. Runs on the
// media thread; the render side feeds the echo canceller's reference.

#ifndef VOICE_CORE_SRC_ENGINE_CAPTURE_CHAIN_H_
#define VOICE_CORE_SRC_ENGINE_CAPTURE_CHAIN_H_

#include <cstdint>

#include "dsp/audio_processor.h"
#include "dsp/voice_detector.h"
#include "dsp/voice_gate.h"
#include "events/core_event.h"

namespace voice_core {

class CaptureChain {
 public:
  CaptureChain(IAudioProcessor& processor, IVoiceDetector& detector, VoiceGate& gate,
               IEventSink& events) noexcept
      : processor_(processor), detector_(detector), gate_(gate), events_(events) {}

  /// Processes one captured frame in place and returns whether it is sent.
  bool processCapture(int16_t* frame);

  /// One frame about to be played (the echo reference).
  void analyzeRender(const int16_t* frame) noexcept { processor_.analyzeRender(frame); }

 private:
  IAudioProcessor& processor_;
  IVoiceDetector& detector_;
  VoiceGate& gate_;
  IEventSink& events_;
  bool talking_ = false;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_ENGINE_CAPTURE_CHAIN_H_
