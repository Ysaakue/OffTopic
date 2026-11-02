// libFuzzer target: the audio datagram parser must never crash or hit UB on
// arbitrary input, and whatever it accepts must round-trip through the writer.

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "net/audio_packet.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  using voice_core::ParsedPacket;
  ParsedPacket packet;
  if (voice_core::parsePacket(data, size, &packet) != voice_core::PacketError::kNone) {
    return 0;
  }
  (void)voice_core::parseKeepaliveBody(packet.payload, packet.payloadSize);

  std::vector<uint8_t> rewritten(voice_core::kMaxDatagramBytes);
  const size_t written = voice_core::writePacket(packet.header, packet.payload, packet.payloadSize,
                                                 rewritten.data(), rewritten.size());
  // Same length, same bytes except the reserved bit, which is always written as 0.
  if (written != size || std::memcmp(rewritten.data() + 1, data + 1, size - 1) != 0 ||
      (rewritten[0] | 0x08U) != (data[0] | 0x08U)) {
    std::abort();
  }
  return 0;
}
