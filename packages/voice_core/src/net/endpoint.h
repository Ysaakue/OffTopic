// IPv4 address + port of a peer. The host is "just an endpoint" (PROTOCOL.md):
// nothing here assumes it is on the local network.

#ifndef VOICE_CORE_SRC_NET_ENDPOINT_H_
#define VOICE_CORE_SRC_NET_ENDPOINT_H_

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace voice_core {

struct Endpoint {
  uint32_t address = 0;  // host byte order
  uint16_t port = 0;

  friend bool operator==(const Endpoint& a, const Endpoint& b) noexcept {
    return a.address == b.address && a.port == b.port;
  }
  friend bool operator!=(const Endpoint& a, const Endpoint& b) noexcept { return !(a == b); }
};

/// Parses a dotted-quad IPv4 address ("192.168.43.1"). Rejects anything else:
/// empty parts, more than three digits, values above 255, signs or spaces.
[[nodiscard]] std::optional<uint32_t> parseIpv4(std::string_view text) noexcept;

/// Formats an address in host byte order as a dotted quad.
[[nodiscard]] std::string formatIpv4(uint32_t address);

/// "a.b.c.d:port".
[[nodiscard]] std::string formatEndpoint(const Endpoint& endpoint);

/// True for addresses a voice stream may target: not 0.0.0.0, not the limited
/// broadcast address and not multicast (224.0.0.0/4) — see PROTOCOL.md.
[[nodiscard]] bool isUnicast(uint32_t address) noexcept;

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_ENDPOINT_H_
