#include "codec/opus_codec.h"

#include <opus.h>

#include <algorithm>

#include "config/core_config.h"

namespace voice_core {
namespace {

// libopus takes opus_int32 for every ctl value; the request constants are
// passed directly to avoid the C-style casts inside the OPUS_SET_* macros.
opus_int32 toOpusBool(bool value) noexcept { return value ? 1 : 0; }

}  // namespace

OpusEncoderParams OpusEncoderParams::fromConfig(const CoreConfig& config) noexcept {
  OpusEncoderParams params;
  params.sampleRateHz = config.sampleRateHz;
  params.frameSamples = config.frameSamples;
  params.bitrateBps = config.bitrateBps;
  params.fec = config.fecEnabled;
  params.expectedLossPct = config.expectedLossPct;
  params.dtx = config.dtxEnabled;
  params.complexity = config.opusComplexity;
  return params;
}

// --- Encoder

void OpusFrameEncoder::Deleter::operator()(OpusEncoder* encoder) const noexcept {
  opus_encoder_destroy(encoder);
}

Expected<OpusFrameEncoder> OpusFrameEncoder::create(const OpusEncoderParams& params) {
  int error = OPUS_OK;
  OpusEncoder* raw = opus_encoder_create(params.sampleRateHz, 1, OPUS_APPLICATION_VOIP, &error);
  if (raw == nullptr) {
    return Status::kCodec;
  }
  OpusFrameEncoder encoder(raw, params.frameSamples);
  const struct {
    int request;
    opus_int32 value;
  } settings[] = {
      {OPUS_SET_BITRATE_REQUEST, params.bitrateBps},
      {OPUS_SET_INBAND_FEC_REQUEST, toOpusBool(params.fec)},
      {OPUS_SET_PACKET_LOSS_PERC_REQUEST, params.expectedLossPct},
      {OPUS_SET_DTX_REQUEST, toOpusBool(params.dtx)},
      {OPUS_SET_COMPLEXITY_REQUEST, params.complexity},
      {OPUS_SET_SIGNAL_REQUEST, OPUS_SIGNAL_VOICE},
  };
  for (const auto& setting : settings) {
    if (opus_encoder_ctl(raw, setting.request, setting.value) != OPUS_OK) {
      return Status::kCodec;
    }
  }
  return encoder;
}

int OpusFrameEncoder::encode(const int16_t* pcm, uint8_t* out, std::size_t capacity) noexcept {
  const auto maxBytes = static_cast<opus_int32>(std::min<std::size_t>(capacity, INT32_MAX));
  return opus_encode(encoder_.get(), pcm, frameSamples_, out, maxBytes);
}

bool OpusFrameEncoder::hasFec(const uint8_t* packet, std::size_t size) noexcept {
  return opus_packet_has_lbrr(packet, static_cast<opus_int32>(size)) > 0;
}

int OpusFrameEncoder::getInt(int request) const noexcept {
  opus_int32 value = 0;
  opus_encoder_ctl(encoder_.get(), request, &value);
  return value;
}

int OpusFrameEncoder::bitrate() const noexcept { return getInt(OPUS_GET_BITRATE_REQUEST); }
bool OpusFrameEncoder::inbandFec() const noexcept {
  return getInt(OPUS_GET_INBAND_FEC_REQUEST) != 0;
}
int OpusFrameEncoder::packetLossPercent() const noexcept {
  return getInt(OPUS_GET_PACKET_LOSS_PERC_REQUEST);
}
bool OpusFrameEncoder::dtx() const noexcept { return getInt(OPUS_GET_DTX_REQUEST) != 0; }
int OpusFrameEncoder::complexity() const noexcept { return getInt(OPUS_GET_COMPLEXITY_REQUEST); }

// --- Decoder

void OpusFrameDecoder::Deleter::operator()(OpusDecoder* decoder) const noexcept {
  opus_decoder_destroy(decoder);
}

Expected<OpusFrameDecoder> OpusFrameDecoder::create(int sampleRateHz, int frameSamples) {
  int error = OPUS_OK;
  OpusDecoder* raw = opus_decoder_create(sampleRateHz, 1, &error);
  if (raw == nullptr) {
    return Status::kCodec;
  }
  return OpusFrameDecoder(raw, frameSamples);
}

int OpusFrameDecoder::decode(const uint8_t* packet, std::size_t size, int16_t* pcm) noexcept {
  return run(packet, size, pcm, false);
}

int OpusFrameDecoder::decodeFec(const uint8_t* nextPacket, std::size_t size,
                                int16_t* pcm) noexcept {
  return run(nextPacket, size, pcm, true);
}

int OpusFrameDecoder::conceal(int16_t* pcm) noexcept { return run(nullptr, 0, pcm, false); }

int OpusFrameDecoder::run(const uint8_t* packet, std::size_t size, int16_t* pcm,
                          bool fec) noexcept {
  const int decoded = opus_decode(decoder_.get(), packet, static_cast<opus_int32>(size), pcm,
                                  frameSamples_, fec ? 1 : 0);
  if (decoded < 0) {
    return decoded;
  }
  std::fill(pcm + decoded, pcm + frameSamples_, int16_t{0});
  return frameSamples_;
}

}  // namespace voice_core
