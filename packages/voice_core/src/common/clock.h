// Monotonic time source. Logic receives timestamps as arguments or reads an
// injected IClock, so tests never depend on real time.

#ifndef VOICE_CORE_SRC_COMMON_CLOCK_H_
#define VOICE_CORE_SRC_COMMON_CLOCK_H_

#include <cstdint>

namespace voice_core {

inline constexpr uint64_t kMicrosPerMilli = 1000;

class IClock {
 public:
  virtual ~IClock() = default;
  IClock() = default;
  IClock(const IClock&) = delete;
  IClock& operator=(const IClock&) = delete;
  IClock(IClock&&) = delete;
  IClock& operator=(IClock&&) = delete;

  /// Microseconds since an arbitrary fixed origin; never goes backwards.
  [[nodiscard]] virtual uint64_t nowUs() const noexcept = 0;
};

/// std::chrono::steady_clock.
class SteadyClock final : public IClock {
 public:
  [[nodiscard]] uint64_t nowUs() const noexcept override;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_COMMON_CLOCK_H_
