#include "jitter/target_delay_estimator.h"

#include <algorithm>
#include <limits>

#include "net/sequence.h"

namespace voice_core {
namespace {

constexpr int64_t kMicrosPerSecond = 1000000;
constexpr int64_t kMicrosPerMilli = 1000;

}  // namespace

TargetDelayEstimator::TargetDelayEstimator(const TargetDelayParams& params) noexcept
    : params_(params),
      packetsPerBucket_(std::max(1, params.windowMs / params.frameMs / kBuckets)) {}

void TargetDelayEstimator::onPacket(uint64_t arrivalUs, uint32_t timestamp) noexcept {
  if (hasTimestamp_) {
    extendedTimestamp_ += timestampDelta(timestamp, lastTimestamp_);
  } else {
    extendedTimestamp_ = timestamp;
    hasTimestamp_ = true;
  }
  lastTimestamp_ = timestamp;

  const int64_t sentUs = extendedTimestamp_ * kMicrosPerSecond / params_.sampleRateHz;
  const int64_t transitUs = static_cast<int64_t>(arrivalUs) - sentUs;

  Bucket& bucket = buckets_[static_cast<std::size_t>(current_)];
  if (bucket.packets == 0) {
    bucket.minTransitUs = transitUs;
    bucket.maxTransitUs = transitUs;
  } else {
    bucket.minTransitUs = std::min(bucket.minTransitUs, transitUs);
    bucket.maxTransitUs = std::max(bucket.maxTransitUs, transitUs);
  }
  if (++bucket.packets == packetsPerBucket_) {
    windowReady_ = true;
    current_ = (current_ + 1) % kBuckets;
    buckets_[static_cast<std::size_t>(current_)] = Bucket{};
  }
}

int TargetDelayEstimator::targetMs() const noexcept {
  if (!windowReady_) {
    return params_.initialMs;
  }
  int64_t minTransit = std::numeric_limits<int64_t>::max();
  int64_t maxTransit = std::numeric_limits<int64_t>::min();
  for (const Bucket& bucket : buckets_) {
    if (bucket.packets > 0) {
      minTransit = std::min(minTransit, bucket.minTransitUs);
      maxTransit = std::max(maxTransit, bucket.maxTransitUs);
    }
  }
  const int64_t spreadMs = (maxTransit - minTransit + kMicrosPerMilli - 1) / kMicrosPerMilli;
  const int64_t frames = (spreadMs + params_.frameMs - 1) / params_.frameMs + 1;
  const int64_t target = frames * params_.frameMs;
  return static_cast<int>(std::clamp<int64_t>(target, params_.minMs, params_.maxMs));
}

void TargetDelayEstimator::reset() noexcept {
  buckets_ = {};
  current_ = 0;
  windowReady_ = false;
  hasTimestamp_ = false;
  lastTimestamp_ = 0;
  extendedTimestamp_ = 0;
}

}  // namespace voice_core
