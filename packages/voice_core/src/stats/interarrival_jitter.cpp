#include "stats/interarrival_jitter.h"

#include <cmath>

#include "net/sequence.h"

namespace voice_core {
namespace {

constexpr double kGain = 1.0 / 16.0;  // RFC 3550 smoothing factor
constexpr int64_t kMicrosPerSecond = 1000000;
constexpr double kMillisPerSecond = 1000.0;

}  // namespace

void InterarrivalJitter::onPacket(uint64_t arrivalUs, uint32_t timestamp) noexcept {
  const int64_t arrivalSamples =
      static_cast<int64_t>(arrivalUs) * sampleRateHz_ / kMicrosPerSecond;
  if (hasPrevious_) {
    const int64_t transitChange = (arrivalSamples - previousArrivalSamples_) -
                                  timestampDelta(timestamp, previousTimestamp_);
    jitterSamples_ += (std::fabs(static_cast<double>(transitChange)) - jitterSamples_) * kGain;
  }
  hasPrevious_ = true;
  previousArrivalSamples_ = arrivalSamples;
  previousTimestamp_ = timestamp;
}

double InterarrivalJitter::jitterMs() const noexcept {
  return jitterSamples_ * kMillisPerSecond / sampleRateHz_;
}

void InterarrivalJitter::reset() noexcept {
  hasPrevious_ = false;
  previousArrivalSamples_ = 0;
  previousTimestamp_ = 0;
  jitterSamples_ = 0.0;
}

}  // namespace voice_core
