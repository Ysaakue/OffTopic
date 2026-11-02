// Packet loss from sequence numbers, in the spirit of RFC 3550 (appendix A.3):
// expected = extended highest seq - base seq + 1; lost = expected - received.

#ifndef VOICE_CORE_SRC_STATS_LOSS_TRACKER_H_
#define VOICE_CORE_SRC_STATS_LOSS_TRACKER_H_

#include <cstdint>

namespace voice_core {

class LossTracker {
 public:
  /// Feeds one received (non-duplicate) audio packet.
  void onPacket(uint16_t seq) noexcept;

  /// Loss since the previous call, in percent [0, 100]. 0 without traffic.
  [[nodiscard]] float takeIntervalLossPct() noexcept;

  [[nodiscard]] uint64_t expected() const noexcept;
  [[nodiscard]] uint64_t received() const noexcept { return received_; }
  /// Cumulative loss; never negative (late duplicates can exceed expected).
  [[nodiscard]] uint64_t lost() const noexcept;

  void reset() noexcept;

 private:
  bool started_ = false;
  uint16_t baseSeq_ = 0;
  uint16_t highestSeq_ = 0;
  uint64_t cycles_ = 0;  // number of seq wraps, times 65536
  uint64_t received_ = 0;
  uint64_t expectedAtInterval_ = 0;
  uint64_t receivedAtInterval_ = 0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_STATS_LOSS_TRACKER_H_
