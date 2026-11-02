// Interarrival jitter as defined by RFC 3550, section 6.4.1:
//   D(i,j) = (Rj - Ri) - (Sj - Si),   J += (|D| - J) / 16

#ifndef VOICE_CORE_SRC_STATS_INTERARRIVAL_JITTER_H_
#define VOICE_CORE_SRC_STATS_INTERARRIVAL_JITTER_H_

#include <cstdint>

namespace voice_core {

class InterarrivalJitter {
 public:
  explicit InterarrivalJitter(int sampleRateHz) noexcept : sampleRateHz_(sampleRateHz) {}

  /// Feeds one audio packet: arrival time and its 32-bit sample timestamp.
  void onPacket(uint64_t arrivalUs, uint32_t timestamp) noexcept;

  [[nodiscard]] double jitterMs() const noexcept;

  void reset() noexcept;

 private:
  const int sampleRateHz_;
  bool hasPrevious_ = false;
  int64_t previousArrivalSamples_ = 0;
  uint32_t previousTimestamp_ = 0;
  double jitterSamples_ = 0.0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_STATS_INTERARRIVAL_JITTER_H_
