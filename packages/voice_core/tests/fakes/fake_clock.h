// Manually advanced IClock.

#ifndef VOICE_CORE_TESTS_FAKES_FAKE_CLOCK_H_
#define VOICE_CORE_TESTS_FAKES_FAKE_CLOCK_H_

#include <atomic>
#include <cstdint>

#include "common/clock.h"

namespace voice_core::testing {

class FakeClock final : public IClock {
 public:
  explicit FakeClock(uint64_t startUs = 1'000'000) : nowUs_(startUs) {}

  [[nodiscard]] uint64_t nowUs() const noexcept override { return nowUs_.load(); }

  void advanceUs(uint64_t us) { nowUs_ += us; }
  void advanceMs(uint64_t ms) { nowUs_ += ms * kMicrosPerMilli; }

 private:
  std::atomic<uint64_t> nowUs_;
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_FAKE_CLOCK_H_
