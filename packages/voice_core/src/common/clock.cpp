#include "common/clock.h"

#include <chrono>

namespace voice_core {

uint64_t SteadyClock::nowUs() const noexcept {
  const auto elapsed = std::chrono::steady_clock::now().time_since_epoch();
  return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(elapsed).count());
}

}  // namespace voice_core
