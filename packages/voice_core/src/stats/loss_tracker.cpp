#include "stats/loss_tracker.h"

#include "net/sequence.h"

namespace voice_core {
namespace {

constexpr uint64_t kSeqCycle = 65536;
constexpr float kPercent = 100.0F;

}  // namespace

void LossTracker::onPacket(uint16_t seq) noexcept {
  if (!started_) {
    started_ = true;
    baseSeq_ = seq;
    highestSeq_ = seq;
  } else if (seqNewer(seq, highestSeq_)) {
    if (seq < highestSeq_) {
      cycles_ += kSeqCycle;
    }
    highestSeq_ = seq;
  }
  ++received_;
}

uint64_t LossTracker::expected() const noexcept {
  if (!started_) {
    return 0;
  }
  return cycles_ + highestSeq_ - baseSeq_ + 1;
}

uint64_t LossTracker::lost() const noexcept {
  const uint64_t total = expected();
  return received_ >= total ? 0 : total - received_;
}

float LossTracker::takeIntervalLossPct() noexcept {
  const uint64_t expectedNow = expected();
  const uint64_t expectedInterval = expectedNow - expectedAtInterval_;
  const uint64_t receivedInterval = received_ - receivedAtInterval_;
  expectedAtInterval_ = expectedNow;
  receivedAtInterval_ = received_;
  if (expectedInterval == 0 || receivedInterval >= expectedInterval) {
    return 0.0F;
  }
  return static_cast<float>(expectedInterval - receivedInterval) * kPercent /
         static_cast<float>(expectedInterval);
}

void LossTracker::reset() noexcept { *this = LossTracker(); }

}  // namespace voice_core
