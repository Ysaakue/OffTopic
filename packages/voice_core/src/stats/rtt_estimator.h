// Round-trip time from keepalive PING/PONG pairs, smoothed like TCP's SRTT
// (RFC 6298: SRTT += (R - SRTT) / 8).

#ifndef VOICE_CORE_SRC_STATS_RTT_ESTIMATOR_H_
#define VOICE_CORE_SRC_STATS_RTT_ESTIMATOR_H_

#include <cstdint>

namespace voice_core {

class RttEstimator {
 public:
  /// One measurement from a PONG: `nowMs - originMs` with 32-bit wrapping.
  /// Implausible values (above 10 s, e.g. a stale PONG) are ignored.
  void onPong(uint32_t nowMs, uint32_t originMs) noexcept;

  /// Smoothed RTT in ms, or -1 before the first measurement.
  [[nodiscard]] int smoothedMs() const noexcept;
  [[nodiscard]] int lastMs() const noexcept { return lastMs_; }

  void reset() noexcept;

 private:
  bool hasSample_ = false;
  double smoothedMs_ = 0.0;
  int lastMs_ = -1;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_STATS_RTT_ESTIMATOR_H_
