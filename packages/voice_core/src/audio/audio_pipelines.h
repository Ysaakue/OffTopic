// What the audio callback does: move samples between the device and the
// SPSC rings shared with the media thread. Nothing else runs on that thread.

#ifndef VOICE_CORE_SRC_AUDIO_AUDIO_PIPELINES_H_
#define VOICE_CORE_SRC_AUDIO_AUDIO_PIPELINES_H_

#include <atomic>
#include <cstddef>
#include <cstdint>

#include "audio/audio_device.h"
#include "audio/spsc_ring_buffer.h"

namespace voice_core {

/// Captured samples -> capture ring. A full ring drops the excess and counts it.
class CapturePipeline {
 public:
  explicit CapturePipeline(SpscRingBuffer<int16_t>& ring) noexcept : ring_(ring) {}

  void onInput(const int16_t* samples, std::size_t frames) noexcept;

  /// Number of callbacks that could not store every sample.
  [[nodiscard]] uint32_t overruns() const noexcept { return overruns_.load(std::memory_order_relaxed); }

 private:
  SpscRingBuffer<int16_t>& ring_;
  std::atomic<uint32_t> overruns_{0};
};

/// Playout ring -> device. A short ring is padded with silence and counted.
class PlayoutPipeline {
 public:
  explicit PlayoutPipeline(SpscRingBuffer<int16_t>& ring) noexcept : ring_(ring) {}

  void onOutput(int16_t* samples, std::size_t frames) noexcept;

  /// Media thread: samples played since the previous call. A device may
  /// drain a whole burst at once (miniaudio fills a 40 ms AAudio burst with
  /// several back-to-back callbacks on the emulator), so the media loop keeps
  /// at least the largest amount it saw consumed between two of its passes.
  std::size_t takeConsumed() noexcept { return consumed_.exchange(0, std::memory_order_relaxed); }

  /// Number of callbacks that had to play silence for part of the period.
  [[nodiscard]] uint32_t underruns() const noexcept {
    return underruns_.load(std::memory_order_relaxed);
  }

 private:
  SpscRingBuffer<int16_t>& ring_;
  std::atomic<uint32_t> underruns_{0};
  std::atomic<std::size_t> consumed_{0};
};

/// The device callback: both pipelines, in one full-duplex call.
class DuplexAudioCallback final : public IAudioCallback {
 public:
  DuplexAudioCallback(CapturePipeline& capture, PlayoutPipeline& playout) noexcept
      : capture_(capture), playout_(playout) {}

  void onAudio(const int16_t* input, int16_t* output, std::size_t frames) noexcept override;

 private:
  CapturePipeline& capture_;
  PlayoutPipeline& playout_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_AUDIO_AUDIO_PIPELINES_H_
