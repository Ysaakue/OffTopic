// Byte-exact checks against the test vectors in docs/PROTOCOL.md, section 1.3.

#include "net/audio_packet.h"

#include <gtest/gtest.h>

#include <array>
#include <vector>

namespace voice_core {
namespace {

using Bytes = std::vector<uint8_t>;

Bytes write(const AudioHeader& header, const Bytes& payload) {
  Bytes out(kMaxDatagramBytes);
  const std::size_t size =
      writePacket(header, payload.data(), payload.size(), out.data(), out.size());
  out.resize(size);
  return out;
}

Bytes keepalive(const AudioHeader& header, KeepaliveKind kind, uint32_t originMs) {
  std::array<uint8_t, kKeepaliveBodyBytes> body{};
  EXPECT_EQ(writeKeepaliveBody(KeepaliveBody{kind, originMs}, body.data(), body.size()),
            kKeepaliveBodyBytes);
  return write(header, Bytes(body.begin(), body.end()));
}

AudioHeader header(uint8_t flags, uint8_t participant, uint16_t seq, uint32_t timestamp) {
  AudioHeader h;
  h.flags = flags;
  h.participantId = participant;
  h.seq = seq;
  h.timestamp = timestamp;
  return h;
}

TEST(AudioPacketVectorsTest, AudioWithFec) {
  EXPECT_EQ(write(header(packet_flags::kFec, 3, 0x1234, 0x00ABCDEF), {0xDE, 0xAD}),
            (Bytes{0x12, 0x03, 0x12, 0x34, 0x00, 0xAB, 0xCD, 0xEF, 0xDE, 0xAD}));
}

TEST(AudioPacketVectorsTest, TalkspurtStartWithFec) {
  EXPECT_EQ(write(header(packet_flags::kTalkspurtStart | packet_flags::kFec, 1, 0, 0), {0x01}),
            (Bytes{0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01}));
}

TEST(AudioPacketVectorsTest, KeepalivePing) {
  EXPECT_EQ(keepalive(header(packet_flags::kKeepalive, 0, 0xFFFF, 0xFFFFFFC0),
                      KeepaliveKind::kPing, 123456),
            (Bytes{0x11, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00,
                   0x01, 0xE2, 0x40}));
}

TEST(AudioPacketVectorsTest, KeepalivePong) {
  EXPECT_EQ(keepalive(header(packet_flags::kKeepalive, 255, 0xFFFF, 0xFFFFFFC0),
                      KeepaliveKind::kPong, 123456),
            (Bytes{0x11, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0x01, 0x00, 0x00, 0x00, 0x00,
                   0x01, 0xE2, 0x40}));
}

TEST(AudioPacketVectorsTest, EmptyKeepalive) {
  EXPECT_EQ(write(header(packet_flags::kKeepalive, 7, 9, 2880), {}),
            (Bytes{0x11, 0x07, 0x00, 0x09, 0x00, 0x00, 0x0B, 0x40}));
}

TEST(ParsePacketTest, ReadsEveryField) {
  const Bytes data{0x12, 0x03, 0x12, 0x34, 0x00, 0xAB, 0xCD, 0xEF, 0xDE, 0xAD};
  ParsedPacket packet;

  ASSERT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kNone);

  EXPECT_EQ(packet.header.flags, packet_flags::kFec);
  EXPECT_EQ(packet.header.participantId, 3);
  EXPECT_EQ(packet.header.seq, 0x1234);
  EXPECT_EQ(packet.header.timestamp, 0x00ABCDEFU);
  ASSERT_EQ(packet.payloadSize, 2U);
  EXPECT_EQ(packet.payload, data.data() + kAudioHeaderBytes);
  EXPECT_EQ(packet.payload[0], 0xDE);
}

TEST(ParsePacketTest, RoundTripsEveryFlagCombination) {
  for (uint8_t flags = 0; flags <= packet_flags::kKnownMask; ++flags) {
    const bool keepaliveFlag = (flags & packet_flags::kKeepalive) != 0;
    const Bytes payload = keepaliveFlag ? Bytes{} : Bytes{0x42};
    const Bytes data = write(header(flags, 200, 65535, 0xFFFFFFFFU), payload);
    ParsedPacket packet;

    ASSERT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kNone) << int{flags};
    EXPECT_EQ(packet.header.flags, flags);
    EXPECT_EQ(packet.header.participantId, 200);
    EXPECT_EQ(packet.header.seq, 65535);
    EXPECT_EQ(packet.header.timestamp, 0xFFFFFFFFU);
  }
}

TEST(ParsePacketTest, IgnoresTheReservedBit) {
  const Bytes data{0x1A, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x05};  // 0x08 | FEC
  ParsedPacket packet;

  ASSERT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kNone);
  EXPECT_EQ(packet.header.flags, packet_flags::kFec);
}

TEST(ParsePacketTest, AcceptsAnEmptyPayload) {
  const Bytes data{0x10, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00};
  ParsedPacket packet;

  ASSERT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kNone);
  EXPECT_EQ(packet.payloadSize, 0U);
}

TEST(ParsePacketTest, RejectsTheProtocolVectors) {
  ParsedPacket packet;
  const Bytes version2{0x22, 0x03, 0x12, 0x34, 0x00, 0xAB, 0xCD, 0xEF, 0xDE, 0xAD};
  const Bytes sevenBytes{0x12, 0x03, 0x12, 0x34, 0x00, 0xAB, 0xCD};
  const Bytes badKeepalive{0x11, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

  EXPECT_EQ(parsePacket(version2.data(), version2.size(), &packet), PacketError::kBadVersion);
  EXPECT_EQ(parsePacket(sevenBytes.data(), sevenBytes.size(), &packet), PacketError::kTooShort);
  EXPECT_EQ(parsePacket(badKeepalive.data(), badKeepalive.size(), &packet),
            PacketError::kBadKeepalive);
  EXPECT_EQ(parsePacket(nullptr, 0, &packet), PacketError::kTooShort);
}

TEST(ParsePacketTest, RejectsAnOversizedPayload) {
  Bytes data(kMaxDatagramBytes + 1, 0);
  data[0] = 0x10;
  ParsedPacket packet;

  EXPECT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kPayloadTooLarge);
  data.pop_back();
  EXPECT_EQ(parsePacket(data.data(), data.size(), &packet), PacketError::kNone);
}

TEST(WritePacketTest, RefusesWhatDoesNotFit) {
  std::array<uint8_t, kAudioHeaderBytes + 1> small{};
  const Bytes payload{1, 2};
  const Bytes huge(kMaxOpusPayloadBytes + 1, 0);
  Bytes big(kMaxDatagramBytes + 8);

  EXPECT_EQ(writePacket(AudioHeader{}, payload.data(), payload.size(), small.data(), small.size()),
            0U);
  EXPECT_EQ(writePacket(AudioHeader{}, huge.data(), huge.size(), big.data(), big.size()), 0U);
}

TEST(WritePacketTest, NeverWritesTheReservedBit) {
  const Bytes data = write(header(0xFF, 0, 0, 0), {});
  EXPECT_EQ(data[0], 0x17);
}

TEST(KeepaliveBodyTest, RoundTrips) {
  std::array<uint8_t, kKeepaliveBodyBytes> body{};
  ASSERT_EQ(writeKeepaliveBody(KeepaliveBody{KeepaliveKind::kPong, 0xFFFFFFFFU}, body.data(),
                               body.size()),
            kKeepaliveBodyBytes);

  const auto parsed = parseKeepaliveBody(body.data(), body.size());

  ASSERT_TRUE(parsed.has_value());
  EXPECT_EQ(parsed->kind, KeepaliveKind::kPong);
  EXPECT_EQ(parsed->originMs, 0xFFFFFFFFU);
}

TEST(KeepaliveBodyTest, RejectsWrongSizesAndKinds) {
  std::array<uint8_t, kKeepaliveBodyBytes> body{};
  body[0] = 2;  // unknown kind

  EXPECT_FALSE(parseKeepaliveBody(body.data(), body.size()).has_value());
  EXPECT_FALSE(parseKeepaliveBody(body.data(), 0).has_value());
  EXPECT_FALSE(parseKeepaliveBody(body.data(), 3).has_value());
  EXPECT_EQ(writeKeepaliveBody(KeepaliveBody{}, body.data(), 7), 0U);
}

}  // namespace
}  // namespace voice_core
