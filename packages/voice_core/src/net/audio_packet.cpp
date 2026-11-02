#include "net/audio_packet.h"

#include <cstring>

namespace voice_core {
namespace {

constexpr int kVersionShift = 4;
constexpr int kByteBits = 8;
constexpr uint32_t kByteMask = 0xFFU;

constexpr std::size_t kVersionFlagsOffset = 0;
constexpr std::size_t kParticipantOffset = 1;
constexpr std::size_t kSeqOffset = 2;
constexpr std::size_t kTimestampOffset = 4;
constexpr std::size_t kKeepaliveKindOffset = 0;
constexpr std::size_t kKeepaliveOriginOffset = 4;

uint16_t readU16(const uint8_t* data) noexcept {
  return static_cast<uint16_t>((static_cast<uint32_t>(data[0]) << kByteBits) | data[1]);
}

uint32_t readU32(const uint8_t* data) noexcept {
  uint32_t value = 0;
  for (std::size_t i = 0; i < sizeof(uint32_t); ++i) {
    value = (value << kByteBits) | data[i];
  }
  return value;
}

void writeU16(uint8_t* out, uint16_t value) noexcept {
  out[0] = static_cast<uint8_t>(value >> kByteBits);
  out[1] = static_cast<uint8_t>(value & kByteMask);
}

void writeU32(uint8_t* out, uint32_t value) noexcept {
  for (std::size_t i = 0; i < sizeof(uint32_t); ++i) {
    const std::size_t shift = (sizeof(uint32_t) - 1 - i) * kByteBits;
    out[i] = static_cast<uint8_t>((value >> shift) & kByteMask);
  }
}

}  // namespace

PacketError parsePacket(const uint8_t* data, std::size_t size, ParsedPacket* out) noexcept {
  if (size < kAudioHeaderBytes) {
    return PacketError::kTooShort;
  }
  const uint8_t versionFlags = data[kVersionFlagsOffset];
  if ((versionFlags >> kVersionShift) != kAudioProtocolVersion) {
    return PacketError::kBadVersion;
  }
  const std::size_t payloadSize = size - kAudioHeaderBytes;
  if (payloadSize > kMaxOpusPayloadBytes) {
    return PacketError::kPayloadTooLarge;
  }
  AudioHeader header;
  header.flags = static_cast<uint8_t>(versionFlags & packet_flags::kKnownMask);
  header.participantId = data[kParticipantOffset];
  header.seq = readU16(data + kSeqOffset);
  header.timestamp = readU32(data + kTimestampOffset);
  if (header.has(packet_flags::kKeepalive) && payloadSize != 0 &&
      payloadSize != kKeepaliveBodyBytes) {
    return PacketError::kBadKeepalive;
  }
  out->header = header;
  out->payload = data + kAudioHeaderBytes;
  out->payloadSize = payloadSize;
  return PacketError::kNone;
}

std::size_t writePacket(const AudioHeader& header, const uint8_t* payload,
                        std::size_t payloadSize, uint8_t* out, std::size_t capacity) noexcept {
  const std::size_t total = kAudioHeaderBytes + payloadSize;
  if (payloadSize > kMaxOpusPayloadBytes || capacity < total) {
    return 0;
  }
  out[kVersionFlagsOffset] = static_cast<uint8_t>(
      (kAudioProtocolVersion << kVersionShift) | (header.flags & packet_flags::kKnownMask));
  out[kParticipantOffset] = header.participantId;
  writeU16(out + kSeqOffset, header.seq);
  writeU32(out + kTimestampOffset, header.timestamp);
  if (payloadSize > 0) {
    std::memcpy(out + kAudioHeaderBytes, payload, payloadSize);
  }
  return total;
}

std::size_t writeKeepaliveBody(const KeepaliveBody& body, uint8_t* out,
                               std::size_t capacity) noexcept {
  if (capacity < kKeepaliveBodyBytes) {
    return 0;
  }
  std::memset(out, 0, kKeepaliveBodyBytes);
  out[kKeepaliveKindOffset] = static_cast<uint8_t>(body.kind);
  writeU32(out + kKeepaliveOriginOffset, body.originMs);
  return kKeepaliveBodyBytes;
}

std::optional<KeepaliveBody> parseKeepaliveBody(const uint8_t* data, std::size_t size) noexcept {
  if (size != kKeepaliveBodyBytes) {
    return std::nullopt;
  }
  const uint8_t kind = data[kKeepaliveKindOffset];
  if (kind != static_cast<uint8_t>(KeepaliveKind::kPing) &&
      kind != static_cast<uint8_t>(KeepaliveKind::kPong)) {
    return std::nullopt;
  }
  return KeepaliveBody{static_cast<KeepaliveKind>(kind), readU32(data + kKeepaliveOriginOffset)};
}

}  // namespace voice_core
