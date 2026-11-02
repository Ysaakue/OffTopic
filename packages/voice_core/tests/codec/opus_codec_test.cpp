#include "codec/opus_codec.h"

#include <gtest/gtest.h>

#include <algorithm>
#include <cmath>
#include <vector>

#include "config/core_config.h"
#include "net/audio_packet.h"
#include "support/allocation_guard.h"

namespace voice_core {
namespace {

using testing::AllocationGuard;

constexpr int kRate = 16000;
constexpr int kFrame = 320;
constexpr double kPi = 3.14159265358979323846;

OpusEncoderParams defaultParams() { return OpusEncoderParams::fromConfig(CoreConfig{}); }

std::vector<int16_t> sine(int frames, double hz, double amplitude = 8000.0) {
  std::vector<int16_t> samples(static_cast<std::size_t>(frames * kFrame));
  for (std::size_t i = 0; i < samples.size(); ++i) {
    samples[i] = static_cast<int16_t>(
        std::lround(amplitude * std::sin(2.0 * kPi * hz * static_cast<double>(i) / kRate)));
  }
  return samples;
}

// Best SNR (dB) over the codec delay, ignoring the first frames (warm-up).
double bestSnrDb(const std::vector<int16_t>& reference, const std::vector<int16_t>& decoded) {
  constexpr std::size_t kSkip = 5 * kFrame;
  constexpr std::size_t kMaxLag = 2 * kFrame;
  double best = -100.0;
  for (std::size_t lag = 0; lag <= kMaxLag; ++lag) {
    double signal = 0.0;
    double error = 0.0;
    for (std::size_t i = kSkip; i + lag < decoded.size(); ++i) {
      const double expected = reference[i];
      const double got = decoded[i + lag];
      signal += expected * expected;
      error += (expected - got) * (expected - got);
    }
    best = std::max(best, 10.0 * std::log10(signal / std::max(error, 1.0)));
  }
  return best;
}

struct Codec {
  OpusFrameEncoder encoder;
  OpusFrameDecoder decoder;
};

Codec makeCodec(const OpusEncoderParams& params = defaultParams()) {
  Expected<OpusFrameEncoder> encoder = OpusFrameEncoder::create(params);
  Expected<OpusFrameDecoder> decoder = OpusFrameDecoder::create(kRate, kFrame);
  EXPECT_TRUE(encoder.hasValue());
  EXPECT_TRUE(decoder.hasValue());
  return Codec{std::move(encoder).value(), std::move(decoder).value()};
}

TEST(OpusEncoderParamsTest, ComeFromTheCoreConfig) {
  CoreConfig config;
  config.bitrateBps = 32000;
  config.fecEnabled = false;
  config.expectedLossPct = 20;
  config.dtxEnabled = false;
  config.opusComplexity = 9;

  const OpusEncoderParams params = OpusEncoderParams::fromConfig(config);

  EXPECT_EQ(params.sampleRateHz, 16000);
  EXPECT_EQ(params.frameSamples, 320);
  EXPECT_EQ(params.bitrateBps, 32000);
  EXPECT_FALSE(params.fec);
  EXPECT_EQ(params.expectedLossPct, 20);
  EXPECT_FALSE(params.dtx);
  EXPECT_EQ(params.complexity, 9);
}

TEST(OpusFrameEncoderTest, AppliesEveryParameter) {
  const Codec codec = makeCodec();

  EXPECT_EQ(codec.encoder.bitrate(), 24000);
  EXPECT_TRUE(codec.encoder.inbandFec());
  EXPECT_EQ(codec.encoder.packetLossPercent(), 10);
  EXPECT_TRUE(codec.encoder.dtx());
  EXPECT_EQ(codec.encoder.complexity(), 5);
  EXPECT_EQ(codec.encoder.frameSamples(), kFrame);
}

TEST(OpusFrameEncoderTest, AppliesDisabledFlags) {
  OpusEncoderParams params = defaultParams();
  params.fec = false;
  params.dtx = false;
  const Codec codec = makeCodec(params);

  EXPECT_FALSE(codec.encoder.inbandFec());
  EXPECT_FALSE(codec.encoder.dtx());
}

TEST(OpusFrameEncoderTest, RejectsInvalidParameters) {
  OpusEncoderParams badRate = defaultParams();
  badRate.sampleRateHz = 11025;
  OpusEncoderParams badBitrate = defaultParams();
  badBitrate.bitrateBps = -5;

  EXPECT_EQ(OpusFrameEncoder::create(badRate).status(), Status::kCodec);
  EXPECT_EQ(OpusFrameEncoder::create(badBitrate).status(), Status::kCodec);
}

TEST(OpusFrameDecoderTest, RejectsAnInvalidRate) {
  EXPECT_EQ(OpusFrameDecoder::create(11025, kFrame).status(), Status::kCodec);
}

TEST(OpusCodecTest, RoundTripsASineWave) {
  Codec codec = makeCodec();
  const std::vector<int16_t> input = sine(50, 440.0);
  std::vector<int16_t> output(input.size());
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);

  for (int frame = 0; frame < 50; ++frame) {
    const auto offset = static_cast<std::size_t>(frame * kFrame);
    const int size = codec.encoder.encode(input.data() + offset, packet.data(), packet.size());
    ASSERT_GT(size, 0);
    ASSERT_EQ(codec.decoder.decode(packet.data(), static_cast<std::size_t>(size),
                                   output.data() + offset),
              kFrame);
  }

  EXPECT_GT(bestSnrDb(input, output), 10.0);
}

TEST(OpusCodecTest, SendsTinyFramesWhileInDtx) {
  Codec codec = makeCodec();
  const std::vector<int16_t> silence(kFrame, 0);
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);
  int smallest = kMaxOpusPayloadBytes;

  for (int frame = 0; frame < 50; ++frame) {
    smallest = std::min(smallest, codec.encoder.encode(silence.data(), packet.data(), packet.size()));
  }

  EXPECT_GT(smallest, 0);
  EXPECT_LE(smallest, 2);
}

TEST(OpusCodecTest, CarriesFecForThePreviousFrame) {
  Codec codec = makeCodec();
  const std::vector<int16_t> input = sine(20, 220.0, 12000.0);
  std::vector<std::vector<uint8_t>> packets;
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);
  for (int frame = 0; frame < 20; ++frame) {
    const int size = codec.encoder.encode(input.data() + frame * kFrame, packet.data(), packet.size());
    ASSERT_GT(size, 0);
    packets.emplace_back(packet.begin(), packet.begin() + size);
  }
  std::vector<int16_t> pcm(kFrame);
  for (int frame = 0; frame < 10; ++frame) {
    ASSERT_EQ(codec.decoder.decode(packets[static_cast<std::size_t>(frame)].data(),
                                   packets[static_cast<std::size_t>(frame)].size(), pcm.data()),
              kFrame);
  }

  // Frame 10 is "lost": rebuild it from the FEC inside packet 11.
  const std::vector<uint8_t>& next = packets[11];
  EXPECT_TRUE(OpusFrameEncoder::hasFec(next.data(), next.size()));
  EXPECT_EQ(codec.decoder.decodeFec(next.data(), next.size(), pcm.data()), kFrame);
  EXPECT_TRUE(std::any_of(pcm.begin(), pcm.end(), [](int16_t s) { return std::abs(s) > 100; }));
  EXPECT_EQ(codec.decoder.decode(next.data(), next.size(), pcm.data()), kFrame);
}

TEST(OpusCodecTest, ReportsNoFecWhenDisabled) {
  OpusEncoderParams params = defaultParams();
  params.fec = false;
  Codec codec = makeCodec(params);
  const std::vector<int16_t> input = sine(5, 220.0, 12000.0);
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);
  int size = 0;
  for (int frame = 0; frame < 5; ++frame) {
    size = codec.encoder.encode(input.data() + frame * kFrame, packet.data(), packet.size());
  }

  EXPECT_FALSE(OpusFrameEncoder::hasFec(packet.data(), static_cast<std::size_t>(size)));
}

TEST(OpusCodecTest, ConcealsALostFrame) {
  Codec codec = makeCodec();
  std::vector<int16_t> pcm(kFrame, 1);

  EXPECT_EQ(codec.decoder.conceal(pcm.data()), kFrame);
  EXPECT_EQ(codec.decoder.frameSamples(), kFrame);
}

TEST(OpusCodecTest, PropagatesErrors) {
  Codec codec = makeCodec();
  const std::vector<int16_t> pcmIn(kFrame, 0);
  std::vector<int16_t> pcm(kFrame);
  std::vector<uint8_t> out(4);
  const std::vector<uint8_t> invalid{0xFF, 0xFF};  // code 3, 63 frames: longer than 120 ms

  EXPECT_LT(codec.encoder.encode(pcmIn.data(), out.data(), 0), 0);
  EXPECT_LT(codec.decoder.decode(invalid.data(), invalid.size(), pcm.data()), 0);
}

TEST(OpusCodecTest, PadsAShorterPacketWithSilence) {
  OpusEncoderParams params = defaultParams();
  params.frameSamples = 160;  // 10 ms packets into a 20 ms decoder
  Expected<OpusFrameEncoder> encoder = OpusFrameEncoder::create(params);
  ASSERT_TRUE(encoder.hasValue());
  Codec codec = makeCodec();
  const std::vector<int16_t> input = sine(1, 440.0);
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);
  const int size = encoder.value().encode(input.data(), packet.data(), packet.size());
  std::vector<int16_t> pcm(kFrame, 7);

  ASSERT_EQ(codec.decoder.decode(packet.data(), static_cast<std::size_t>(size), pcm.data()), kFrame);
  EXPECT_TRUE(std::all_of(pcm.begin() + 160, pcm.end(), [](int16_t s) { return s == 0; }));
}

// Encoding and decoding run on the media thread every 20 ms: no allocation.
TEST(OpusCodecTest, DoesNotAllocatePerFrame) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  Codec codec = makeCodec();
  const std::vector<int16_t> input = sine(1, 440.0);
  std::vector<int16_t> pcm(kFrame);
  std::vector<uint8_t> packet(kMaxOpusPayloadBytes);
  const AllocationGuard guard;

  for (int i = 0; i < 20; ++i) {
    const int size = codec.encoder.encode(input.data(), packet.data(), packet.size());
    codec.decoder.decode(packet.data(), static_cast<std::size_t>(size), pcm.data());
    codec.decoder.conceal(pcm.data());
  }

  EXPECT_EQ(guard.allocations(), 0U);
}

}  // namespace
}  // namespace voice_core
