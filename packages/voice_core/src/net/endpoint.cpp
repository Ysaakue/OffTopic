#include "net/endpoint.h"

#include <cstddef>

namespace voice_core {
namespace {

constexpr int kOctets = 4;
constexpr int kMaxOctetDigits = 3;
constexpr uint32_t kMaxOctet = 255;
constexpr uint32_t kDecimalBase = 10;
constexpr int kBitsPerOctet = 8;
constexpr uint32_t kOctetMask = 0xFFU;
constexpr uint32_t kMulticastMask = 0xF0000000U;
constexpr uint32_t kMulticastPrefix = 0xE0000000U;
constexpr uint32_t kLimitedBroadcast = 0xFFFFFFFFU;

}  // namespace

std::optional<uint32_t> parseIpv4(std::string_view text) noexcept {
  uint32_t address = 0;
  std::size_t position = 0;
  for (int octet = 0; octet < kOctets; ++octet) {
    if (octet > 0) {
      if (position >= text.size() || text[position] != '.') {
        return std::nullopt;
      }
      ++position;
    }
    uint32_t value = 0;
    int digits = 0;
    while (position < text.size() && text[position] >= '0' && text[position] <= '9') {
      if (++digits > kMaxOctetDigits) {
        return std::nullopt;
      }
      value = value * kDecimalBase + static_cast<uint32_t>(text[position] - '0');
      ++position;
    }
    if (digits == 0 || value > kMaxOctet) {
      return std::nullopt;
    }
    address = (address << kBitsPerOctet) | value;
  }
  if (position != text.size()) {
    return std::nullopt;
  }
  return address;
}

std::string formatIpv4(uint32_t address) {
  std::string text;
  for (int octet = kOctets - 1; octet >= 0; --octet) {
    text += std::to_string((address >> (octet * kBitsPerOctet)) & kOctetMask);
    if (octet > 0) {
      text += '.';
    }
  }
  return text;
}

std::string formatEndpoint(const Endpoint& endpoint) {
  return formatIpv4(endpoint.address) + ':' + std::to_string(endpoint.port);
}

bool isUnicast(uint32_t address) noexcept {
  return address != 0 && address != kLimitedBroadcast &&
         (address & kMulticastMask) != kMulticastPrefix;
}

}  // namespace voice_core
