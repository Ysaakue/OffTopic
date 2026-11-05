#include "dsp/webrtc_voice_detector.h"

#include <utility>

#include "common_audio/vad/include/webrtc_vad.h"

namespace voice_core {
namespace {

constexpr int kVadBlockMs = 10;  // the VAD accepts 10, 20 or 30 ms; 10 divides every frame

// WebRTC VAD modes (its API): higher modes report speech less readily.
constexpr int kModeLowBitrate = 1;
constexpr int kModeAggressive = 2;
constexpr int kModeVeryAggressive = 3;

// The most sensitive setting uses the least aggressive mode.
int toVadMode(VadSensitivity sensitivity) noexcept {
  switch (sensitivity) {
    case VadSensitivity::kLow:
      return kModeVeryAggressive;
    case VadSensitivity::kHigh:
      return kModeLowBitrate;
    case VadSensitivity::kMedium:
      break;
  }
  return kModeAggressive;
}

}  // namespace

void WebRtcVoiceDetector::Free::operator()(WebRtcVadInst* vad) const noexcept {
  WebRtcVad_Free(vad);
}

Expected<std::unique_ptr<WebRtcVoiceDetector>> WebRtcVoiceDetector::create(
    const CoreConfig& config) {
  std::unique_ptr<WebRtcVadInst, Free> vad(WebRtcVad_Create());
  // GCOVR_EXCL_START: creation and init fail only on allocation failure
  if (!vad || WebRtcVad_Init(vad.get()) != 0 ||
      WebRtcVad_set_mode(vad.get(), toVadMode(config.vadSensitivity)) != 0) {
    return Status::kInternal;
  }
  // GCOVR_EXCL_STOP
  return std::unique_ptr<WebRtcVoiceDetector>(new WebRtcVoiceDetector(std::move(vad), config));
}

WebRtcVoiceDetector::WebRtcVoiceDetector(std::unique_ptr<WebRtcVadInst, Free> vad,
                                         const CoreConfig& config) noexcept
    : vad_(std::move(vad)),
      sampleRateHz_(config.sampleRateHz),
      frameSamples_(static_cast<std::size_t>(config.frameSamples)),
      blockSamples_(static_cast<std::size_t>(config.msToSamples(kVadBlockMs))),
      sensitivity_(config.vadSensitivity) {}

bool WebRtcVoiceDetector::isVoice(const int16_t* frame) noexcept {
  bool voice = false;
  // Every block is fed, even after a voiced one, so the VAD's state follows the signal.
  for (std::size_t offset = 0; offset < frameSamples_; offset += blockSamples_) {
    voice = WebRtcVad_Process(vad_.get(), sampleRateHz_, frame + offset, blockSamples_) == 1 || voice;
  }
  return voice;
}

void WebRtcVoiceDetector::setSensitivity(VadSensitivity sensitivity) noexcept {
  if (sensitivity != sensitivity_) {
    // Cannot fail: the instance is initialised and every mode above is valid.
    static_cast<void>(WebRtcVad_set_mode(vad_.get(), toVadMode(sensitivity)));
    sensitivity_ = sensitivity;
  }
}

}  // namespace voice_core
