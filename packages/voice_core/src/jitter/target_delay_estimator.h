// Chooses the jitter buffer target from how late packets arrive.
//
// For every packet, transit = arrival - send time (from its timestamp). Over a
// sliding window (kept as a few buckets of minima and maxima, no allocation),
// the spread max(transit) - min(transit) is how late a packet can be compared
// with the fastest one. The target covers that spread plus one frame, rounded
// up to whole frames and clamped to [min, max]. Before the first bucket fills
// the initial target is used. Spikes raise the target at once; it decays when
// they leave the window.

#ifndef VOICE_CORE_SRC_JITTER_TARGET_DELAY_ESTIMATOR_H_
#define VOICE_CORE_SRC_JITTER_TARGET_DELAY_ESTIMATOR_H_

#include <array>
#include <cstdint>

namespace voice_core {

struct TargetDelayParams {
  int sampleRateHz = 0;
  int frameMs = 0;
  int minMs = 0;
  int initialMs = 0;
  int maxMs = 0;
  int windowMs = 0;
};

class TargetDelayEstimator {
 public:
  static constexpr int kBuckets = 4;

  explicit TargetDelayEstimator(const TargetDelayParams& params) noexcept;

  void onPacket(uint64_t arrivalUs, uint32_t timestamp) noexcept;

  [[nodiscard]] int targetMs() const noexcept;

  void reset() noexcept;

 private:
  struct Bucket {
    int64_t minTransitUs = 0;
    int64_t maxTransitUs = 0;
    int packets = 0;
  };

  const TargetDelayParams params_;
  const int packetsPerBucket_;
  std::array<Bucket, kBuckets> buckets_{};
  int current_ = 0;
  bool windowReady_ = false;  // the first bucket is complete
  bool hasTimestamp_ = false;
  uint32_t lastTimestamp_ = 0;
  int64_t extendedTimestamp_ = 0;  // unwrapped, in samples
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_JITTER_TARGET_DELAY_ESTIMATOR_H_
