// Serial-number arithmetic for the wrapping 16-bit seq and 32-bit timestamp
// fields of the audio header (PROTOCOL.md, section 1).

#ifndef VOICE_CORE_SRC_NET_SEQUENCE_H_
#define VOICE_CORE_SRC_NET_SEQUENCE_H_

#include <cstdint>

namespace voice_core {

/// Signed distance a - b, in [-32768, 32767]. Positive means `a` is newer.
[[nodiscard]] constexpr int seqDelta(uint16_t a, uint16_t b) noexcept {
  return static_cast<int16_t>(static_cast<uint16_t>(a - b));
}

/// True when `a` comes after `b`. Exactly half a cycle apart is neither.
[[nodiscard]] constexpr bool seqNewer(uint16_t a, uint16_t b) noexcept { return seqDelta(a, b) > 0; }

/// Signed distance a - b of two wrapping 32-bit timestamps.
[[nodiscard]] constexpr int32_t timestampDelta(uint32_t a, uint32_t b) noexcept {
  return static_cast<int32_t>(a - b);
}

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_SEQUENCE_H_
