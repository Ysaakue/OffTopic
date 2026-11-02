#include "audio/audio_pipelines.h"

#include <algorithm>

namespace voice_core {

void CapturePipeline::onInput(const int16_t* samples, std::size_t frames) noexcept {
  if (samples == nullptr) {
    return;  // no capture side (output-only device)
  }
  if (ring_.write(samples, frames) < frames) {
    overruns_.fetch_add(1, std::memory_order_relaxed);
  }
}

void PlayoutPipeline::onOutput(int16_t* samples, std::size_t frames) noexcept {
  if (samples == nullptr) {
    return;  // no playback side (input-only device)
  }
  consumed_.fetch_add(frames, std::memory_order_relaxed);
  const std::size_t read = ring_.read(samples, frames);
  if (read < frames) {
    std::fill(samples + read, samples + frames, int16_t{0});
    underruns_.fetch_add(1, std::memory_order_relaxed);
  }
}

void DuplexAudioCallback::onAudio(const int16_t* input, int16_t* output,
                                  std::size_t frames) noexcept {
  capture_.onInput(input, frames);
  playout_.onOutput(output, frames);
}

}  // namespace voice_core
