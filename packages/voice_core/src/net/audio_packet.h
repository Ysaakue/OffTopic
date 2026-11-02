// Audio datagram codec: the 8-byte big-endian header and the keepalive body
// defined in docs/PROTOCOL.md, section 1. Pure functions, no allocation.

#ifndef VOICE_CORE_SRC_NET_AUDIO_PACKET_H_
#define VOICE_CORE_SRC_NET_AUDIO_PACKET_H_

#include <cstddef>
#include <cstdint>
#include <optional>

namespace voice_core {

inline constexpr uint8_t kAudioProtocolVersion = 1;
inline constexpr std::size_t kAudioHeaderBytes = 8;
inline constexpr std::size_t kMaxOpusPayloadBytes = 1275;
inline constexpr std::size_t kMaxDatagramBytes = kAudioHeaderBytes + kMaxOpusPayloadBytes;
inline constexpr std::size_t kKeepaliveBodyBytes = 8;

inline constexpr uint8_t kParticipantHost = 0;
inline constexpr uint8_t kParticipantUnassigned = 255;

/// Header flag bits (low nibble of byte 0; bit 3 is reserved).
namespace packet_flags {
inline constexpr uint8_t kKeepalive = 0x01;
inline constexpr uint8_t kFec = 0x02;
inline constexpr uint8_t kTalkspurtStart = 0x04;
inline constexpr uint8_t kKnownMask = kKeepalive | kFec | kTalkspurtStart;
}  // namespace packet_flags

struct AudioHeader {
  uint8_t flags = 0;
  uint8_t participantId = kParticipantUnassigned;
  uint16_t seq = 0;
  uint32_t timestamp = 0;

  [[nodiscard]] bool has(uint8_t flag) const noexcept { return (flags & flag) != 0; }
};

enum class PacketError : uint8_t { kNone, kTooShort, kBadVersion, kPayloadTooLarge, kBadKeepalive };

struct ParsedPacket {
  AudioHeader header;
  const uint8_t* payload = nullptr;  // points into the parsed buffer
  std::size_t payloadSize = 0;
};

/// Parses a datagram. On kNone, `out` describes it (payload aliases `data`).
[[nodiscard]] PacketError parsePacket(const uint8_t* data, std::size_t size,
                                      ParsedPacket* out) noexcept;

/// Writes header + payload into `out`. Returns the datagram size, or 0 when
/// the payload is too large or `capacity` is too small. Reserved bits are
/// always written as zero.
[[nodiscard]] std::size_t writePacket(const AudioHeader& header, const uint8_t* payload,
                                      std::size_t payloadSize, uint8_t* out,
                                      std::size_t capacity) noexcept;

enum class KeepaliveKind : uint8_t { kPing = 0, kPong = 1 };

struct KeepaliveBody {
  KeepaliveKind kind = KeepaliveKind::kPing;
  uint32_t originMs = 0;
};

/// Writes the 8-byte keepalive body. Returns 8, or 0 when `capacity` is too small.
[[nodiscard]] std::size_t writeKeepaliveBody(const KeepaliveBody& body, uint8_t* out,
                                             std::size_t capacity) noexcept;

/// Parses a keepalive body. Empty bodies and unknown kinds give nullopt.
[[nodiscard]] std::optional<KeepaliveBody> parseKeepaliveBody(const uint8_t* data,
                                                              std::size_t size) noexcept;

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_AUDIO_PACKET_H_
