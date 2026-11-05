#include "dsp/webrtc_audio_processor.h"

#include <utility>

#include "api/audio/audio_processing.h"

namespace voice_core {
namespace {

using ApmConfig = webrtc::AudioProcessing::Config;

constexpr int kApmBlockMs = 10;  // the APM's fixed processing block (its API contract)
constexpr int kMono = 1;

ApmConfig::NoiseSuppression::Level toApmLevel(NoiseSuppression level) noexcept {
  switch (level) {
    case NoiseSuppression::kLow:
      return ApmConfig::NoiseSuppression::kLow;
    case NoiseSuppression::kModerate:
      return ApmConfig::NoiseSuppression::kModerate;
    case NoiseSuppression::kVeryHigh:
      return ApmConfig::NoiseSuppression::kVeryHigh;
    case NoiseSuppression::kOff:   // NS disabled: the level is unused
    case NoiseSuppression::kHigh:
      break;
  }
  return ApmConfig::NoiseSuppression::kHigh;
}

ApmConfig toApmConfig(const CoreConfig& config) noexcept {
  ApmConfig apm;
  apm.pipeline.maximum_internal_processing_rate = config.sampleRateHz;
  apm.high_pass_filter.enabled = config.highPassFilter;
  apm.noise_suppression.enabled = config.noiseSuppression != NoiseSuppression::kOff;
  apm.noise_suppression.level = toApmLevel(config.noiseSuppression);
  apm.gain_controller2.enabled = config.automaticGain;
  apm.gain_controller2.adaptive_digital.enabled = config.automaticGain;
  apm.echo_canceller.enabled = config.echoCancellation;
  apm.echo_canceller.mobile_mode = false;  // AEC3: AECM is far weaker
  return apm;
}

}  // namespace

struct WebRtcAudioProcessor::Apm {
  rtc::scoped_refptr<webrtc::AudioProcessing> module;
  webrtc::StreamConfig stream;
};

Expected<std::unique_ptr<WebRtcAudioProcessor>> WebRtcAudioProcessor::create(
    const CoreConfig& config) {
  rtc::scoped_refptr<webrtc::AudioProcessing> module =
      webrtc::AudioProcessingBuilder().SetConfig(toApmConfig(config)).Create();
  if (!module) {          // GCOVR_EXCL_BR_LINE: the builder fails only on allocation failure
    return Status::kInternal;  // GCOVR_EXCL_LINE: see above
  }
  auto apm = std::make_unique<Apm>(Apm{std::move(module), webrtc::StreamConfig(config.sampleRateHz, kMono)});
  return std::unique_ptr<WebRtcAudioProcessor>(new WebRtcAudioProcessor(std::move(apm), config));
}

WebRtcAudioProcessor::WebRtcAudioProcessor(std::unique_ptr<Apm> apm,
                                           const CoreConfig& config) noexcept
    : apm_(std::move(apm)),
      frameSamples_(static_cast<std::size_t>(config.frameSamples)),
      blockSamples_(static_cast<std::size_t>(config.msToSamples(kApmBlockMs))),
      echoCancellation_(config.echoCancellation),
      renderScratch_(blockSamples_) {}

WebRtcAudioProcessor::~WebRtcAudioProcessor() = default;

void WebRtcAudioProcessor::processCapture(int16_t* frame) noexcept {
  for (std::size_t offset = 0; offset < frameSamples_; offset += blockSamples_) {
    int16_t* block = frame + offset;
    if (apm_->module->ProcessStream(block, apm_->stream, apm_->stream, block) !=
        webrtc::AudioProcessing::kNoError) {
      ++errors_;  // GCOVR_EXCL_LINE: the APM accepts every block of a valid stream
    }
  }
}

void WebRtcAudioProcessor::analyzeRender(const int16_t* frame) noexcept {
  if (!echoCancellation_) {
    return;  // only the echo canceller uses the render signal
  }
  // The 16-bit API writes a processed render block; it goes to the scratch
  // block so the frame being played stays untouched.
  for (std::size_t offset = 0; offset < frameSamples_; offset += blockSamples_) {
    if (apm_->module->ProcessReverseStream(frame + offset, apm_->stream, apm_->stream,
                                           renderScratch_.data()) !=
        webrtc::AudioProcessing::kNoError) {
      ++errors_;  // GCOVR_EXCL_LINE: the APM accepts every block of a valid stream
    }
  }
}

}  // namespace voice_core
