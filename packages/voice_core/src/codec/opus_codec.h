// RAII wrappers over libopus. Construction may allocate; encode/decode never do.

#ifndef VOICE_CORE_SRC_CODEC_OPUS_CODEC_H_
#define VOICE_CORE_SRC_CODEC_OPUS_CODEC_H_

#include <cstddef>
#include <cstdint>
#include <memory>

#include "common/expected.h"

struct OpusEncoder;  // libopus opaque types
struct OpusDecoder;

namespace voice_core {

struct CoreConfig;

struct OpusEncoderParams {
  int sampleRateHz = 0;
  int frameSamples = 0;
  int bitrateBps = 0;
  bool fec = false;
  int expectedLossPct = 0;
  bool dtx = false;
  int complexity = 0;

  static OpusEncoderParams fromConfig(const CoreConfig& config) noexcept;
};

class OpusFrameEncoder {
 public:
  /// Creates a VOIP encoder (mono) and applies every parameter. kCodec on failure.
  static Expected<OpusFrameEncoder> create(const OpusEncoderParams& params);

  /// Encodes exactly `frameSamples` samples. Returns the packet size (>0) or a
  /// negative libopus error code.
  int encode(const int16_t* pcm, uint8_t* out, std::size_t capacity) noexcept;

  /// True when `packet` carries in-band FEC (LBRR) data for the previous frame.
  [[nodiscard]] static bool hasFec(const uint8_t* packet, std::size_t size) noexcept;

  // Read back from libopus (OPUS_GET_*), for tests and diagnostics.
  [[nodiscard]] int bitrate() const noexcept;
  [[nodiscard]] bool inbandFec() const noexcept;
  [[nodiscard]] int packetLossPercent() const noexcept;
  [[nodiscard]] bool dtx() const noexcept;
  [[nodiscard]] int complexity() const noexcept;
  [[nodiscard]] int frameSamples() const noexcept { return frameSamples_; }

 private:
  struct Deleter {
    void operator()(OpusEncoder* encoder) const noexcept;
  };
  OpusFrameEncoder(OpusEncoder* encoder, int frameSamples) noexcept
      : encoder_(encoder), frameSamples_(frameSamples) {}
  [[nodiscard]] int getInt(int request) const noexcept;

  std::unique_ptr<OpusEncoder, Deleter> encoder_;
  int frameSamples_;
};

class OpusFrameDecoder {
 public:
  static Expected<OpusFrameDecoder> create(int sampleRateHz, int frameSamples);

  /// Decodes one packet into `frameSamples` samples (zero padded if the packet
  /// is shorter). Returns frameSamples or a negative libopus error code.
  int decode(const uint8_t* packet, std::size_t size, int16_t* pcm) noexcept;

  /// Rebuilds a lost frame from the FEC data carried by the packet after it.
  int decodeFec(const uint8_t* nextPacket, std::size_t size, int16_t* pcm) noexcept;

  /// Packet loss concealment for one frame.
  int conceal(int16_t* pcm) noexcept;

  [[nodiscard]] int frameSamples() const noexcept { return frameSamples_; }

 private:
  struct Deleter {
    void operator()(OpusDecoder* decoder) const noexcept;
  };
  OpusFrameDecoder(OpusDecoder* decoder, int frameSamples) noexcept
      : decoder_(decoder), frameSamples_(frameSamples) {}
  int run(const uint8_t* packet, std::size_t size, int16_t* pcm, bool fec) noexcept;

  std::unique_ptr<OpusDecoder, Deleter> decoder_;
  int frameSamples_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_CODEC_OPUS_CODEC_H_
