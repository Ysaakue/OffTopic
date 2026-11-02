#include "stats/rtt_estimator.h"

#include <cmath>

namespace voice_core {
namespace {

constexpr uint32_t kMaxPlausibleRttMs = 10000;
constexpr double kGain = 1.0 / 8.0;

}  // namespace

void RttEstimator::onPong(uint32_t nowMs, uint32_t originMs) noexcept {
  const uint32_t sample = nowMs - originMs;
  if (sample > kMaxPlausibleRttMs) {
    return;
  }
  lastMs_ = static_cast<int>(sample);
  if (hasSample_) {
    smoothedMs_ += (static_cast<double>(sample) - smoothedMs_) * kGain;
  } else {
    smoothedMs_ = static_cast<double>(sample);
    hasSample_ = true;
  }
}

int RttEstimator::smoothedMs() const noexcept {
  return hasSample_ ? static_cast<int>(std::lround(smoothedMs_)) : -1;
}

void RttEstimator::reset() noexcept { *this = RttEstimator(); }

}  // namespace voice_core
