#include "session/peer_session.h"

#include <gtest/gtest.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <vector>

#include "fakes/fake_network.h"
#include "fakes/recording_event_sink.h"
#include "support/allocation_guard.h"

namespace voice_core {
namespace {

using testing::AllocationGuard;
using testing::FakeDatagramSocket;
using testing::FakeNetwork;
using testing::RecordingEventSink;

constexpr uint32_t kLoopback = 0x7F000001;
constexpr int kFrame = 320;
constexpr uint64_t kFrameUs = 20000;
constexpr uint64_t kMs = 1000;
constexpr double kPi = 3.14159265358979323846;
const Endpoint kHost{kLoopback, 47801};
const Endpoint kStranger{0x7F000002, 40000};

std::vector<int16_t> sineFrame(int index, double amplitude = 8000.0) {
  std::vector<int16_t> frame(kFrame);
  for (int i = 0; i < kFrame; ++i) {
    const double t = static_cast<double>(index * kFrame + i) / 16000.0;
    frame[static_cast<std::size_t>(i)] =
        static_cast<int16_t>(std::lround(amplitude * std::sin(2.0 * kPi * 300.0 * t)));
  }
  return frame;
}

struct Datagram {
  AudioHeader header;
  std::vector<uint8_t> payload;
  Endpoint to;
};

std::vector<Datagram> parsed(const FakeDatagramSocket& socket) {
  std::vector<Datagram> out;
  for (const testing::SentDatagram& sent : socket.sent()) {
    ParsedPacket packet;
    EXPECT_EQ(parsePacket(sent.bytes.data(), sent.bytes.size(), &packet), PacketError::kNone);
    out.push_back(Datagram{packet.header,
                           std::vector<uint8_t>(packet.payload, packet.payload + packet.payloadSize),
                           sent.to});
  }
  return out;
}

std::vector<Datagram> audioOnly(const std::vector<Datagram>& datagrams) {
  std::vector<Datagram> out;
  std::copy_if(datagrams.begin(), datagrams.end(), std::back_inserter(out),
               [](const Datagram& d) { return !d.header.has(packet_flags::kKeepalive); });
  return out;
}

// Builds Opus audio datagrams as a remote peer would send them.
class RemoteSender {
 public:
  explicit RemoteSender(uint8_t participant) : participant_(participant) {
    Expected<OpusFrameEncoder> encoder =
        OpusFrameEncoder::create(OpusEncoderParams::fromConfig(CoreConfig{}));
    encoder_ = std::make_unique<OpusFrameEncoder>(std::move(encoder).value());
  }

  std::vector<uint8_t> next(uint8_t flags = 0) {
    const std::vector<int16_t> pcm = sineFrame(seq_, 12000.0);
    std::vector<uint8_t> payload(kMaxOpusPayloadBytes);
    const int size = encoder_->encode(pcm.data(), payload.data(), payload.size());
    AudioHeader header;
    header.flags = flags;
    header.participantId = participant_;
    header.seq = static_cast<uint16_t>(seq_);
    header.timestamp = static_cast<uint32_t>(seq_ * kFrame);
    ++seq_;
    std::vector<uint8_t> datagram(kMaxDatagramBytes);
    datagram.resize(writePacket(header, payload.data(), static_cast<std::size_t>(size),
                                datagram.data(), datagram.size()));
    return datagram;
  }

  void skip() { ++seq_; }

 private:
  uint8_t participant_;
  int seq_ = 0;
  std::unique_ptr<OpusFrameEncoder> encoder_;
};

std::vector<uint8_t> keepalive(KeepaliveKind kind, uint32_t originMs, uint8_t participant) {
  AudioHeader header;
  header.flags = packet_flags::kKeepalive;
  header.participantId = participant;
  std::vector<uint8_t> datagram(kMaxDatagramBytes);
  std::size_t size = writePacket(header, nullptr, 0, datagram.data(), datagram.size());
  size += writeKeepaliveBody(KeepaliveBody{kind, originMs}, datagram.data() + size,
                             datagram.size() - size);
  datagram.resize(size);
  return datagram;
}

class PeerSessionTest : public ::testing::Test {
 protected:
  static CoreConfig clientConfig() {
    CoreConfig config;
    config.hostIp = "127.0.0.1";
    config.displayName = "Ana";
    return config;
  }

  static CoreConfig hostConfig() {
    CoreConfig config;
    config.role = Role::kHost;
    config.displayName = "Bia";
    return config;
  }

  std::unique_ptr<PeerSession> make(const CoreConfig& config) {
    Expected<std::unique_ptr<PeerSession>> session = PeerSession::create(config, *socket_, events_);
    EXPECT_TRUE(session.hasValue());
    return std::move(session).value();
  }

  static void deliver(PeerSession& session, const std::vector<uint8_t>& datagram,
                      const Endpoint& from, uint64_t arrivalUs) {
    session.onDatagram(datagram.data(), datagram.size(), from, arrivalUs);
  }

  FakeNetwork network_{kLoopback};
  std::unique_ptr<FakeDatagramSocket> socket_ = network_.open(0);
  RecordingEventSink events_;
};

// --- Creation

TEST_F(PeerSessionTest, FailsWhenOpusRejectsTheConfiguration) {
  CoreConfig badBitrate = clientConfig();
  badBitrate.bitrateBps = -5;  // -1 would be OPUS_BITRATE_MAX, a valid value
  CoreConfig badRate = clientConfig();
  badRate.sampleRateHz = 11025;

  EXPECT_EQ(PeerSession::create(badBitrate, *socket_, events_).status(), Status::kCodec);
  EXPECT_EQ(PeerSession::create(badRate, *socket_, events_).status(), Status::kCodec);
}

TEST_F(PeerSessionTest, TheClientKnowsItsPeerFromTheStart) {
  EXPECT_EQ(make(clientConfig())->peer(), kHost);
  EXPECT_FALSE(make(hostConfig())->peer().has_value());
}

// --- Sending

TEST_F(PeerSessionTest, TheClientSendsNumberedFramesToTheHost) {
  auto session = make(clientConfig());
  for (int i = 0; i < 5; ++i) {
    session->onCaptureFrame(sineFrame(i).data());
  }

  const std::vector<Datagram> sent = parsed(*socket_);
  ASSERT_EQ(sent.size(), 5U);
  for (std::size_t i = 0; i < sent.size(); ++i) {
    EXPECT_EQ(sent[i].to, kHost);
    EXPECT_EQ(sent[i].header.participantId, kParticipantUnassigned);
    EXPECT_EQ(sent[i].header.seq, i);
    EXPECT_EQ(sent[i].header.timestamp, i * kFrame);
    EXPECT_FALSE(sent[i].payload.empty());
    EXPECT_EQ(sent[i].header.has(packet_flags::kTalkspurtStart), i == 0);
    EXPECT_EQ(sent[i].header.has(packet_flags::kFec),
              OpusFrameEncoder::hasFec(sent[i].payload.data(), sent[i].payload.size()));
  }
  EXPECT_EQ(session->stats().packetsSent, 5U);
}

TEST_F(PeerSessionTest, StopsSendingDuringDtxAndMarksTheNextTalkspurt) {
  auto session = make(clientConfig());
  const std::vector<int16_t> silence(kFrame, 0);
  for (int i = 0; i < 3; ++i) {
    session->onCaptureFrame(sineFrame(i).data());
  }
  for (int i = 0; i < 50; ++i) {
    session->onCaptureFrame(silence.data());
  }
  session->onCaptureFrame(sineFrame(53).data());

  const std::vector<Datagram> sent = parsed(*socket_);
  ASSERT_LT(sent.size(), 50U);  // most of the silence was not sent
  EXPECT_EQ(sent.back().header.timestamp, 53U * kFrame);
  int gaps = 0;
  for (std::size_t i = 1; i < sent.size(); ++i) {
    // seq stays consecutive; the timestamp jumps over the unsent frames.
    EXPECT_EQ(sent[i].header.seq, sent[i - 1].header.seq + 1);
    const bool gap = sent[i].header.timestamp - sent[i - 1].header.timestamp > kFrame;
    EXPECT_EQ(sent[i].header.has(packet_flags::kTalkspurtStart), gap) << i;
    gaps += gap ? 1 : 0;
  }
  EXPECT_GE(gaps, 1);
}

TEST_F(PeerSessionTest, DoesNotSendWhileMuted) {
  auto session = make(clientConfig());
  session->onCaptureFrame(sineFrame(0).data());
  session->setMuted(true);
  session->onCaptureFrame(sineFrame(1).data());
  session->onCaptureFrame(sineFrame(2).data());
  session->setMuted(false);
  session->onCaptureFrame(sineFrame(3).data());

  const std::vector<Datagram> sent = parsed(*socket_);
  ASSERT_EQ(sent.size(), 2U);
  EXPECT_EQ(sent[1].header.seq, 1);
  EXPECT_EQ(sent[1].header.timestamp, 3U * kFrame);
  EXPECT_TRUE(sent[1].header.has(packet_flags::kTalkspurtStart));
}

TEST_F(PeerSessionTest, MeasuresTheInputLevelEvenWhenMuted) {
  auto session = make(clientConfig());
  session->setMuted(true);
  std::vector<int16_t> loud(kFrame, 0);
  loud[10] = -32768;

  session->onCaptureFrame(loud.data());

  EXPECT_FLOAT_EQ(session->stats().inputLevel, 1.0F);
}

TEST_F(PeerSessionTest, CountsFailedSends) {
  auto session = make(clientConfig());
  socket_->failSends(true);

  session->onCaptureFrame(sineFrame(0).data());

  EXPECT_EQ(session->stats().sendErrors, 1U);
  EXPECT_EQ(session->stats().packetsSent, 0U);
}

TEST_F(PeerSessionTest, TheHostWaitsForAPeerBeforeSending) {
  auto session = make(hostConfig());
  session->onCaptureFrame(sineFrame(0).data());
  session->tick(1000 * kMs);
  EXPECT_TRUE(socket_->sent().empty());

  deliver(*session, keepalive(KeepaliveKind::kPing, 5, 255), kStranger, 1000 * kMs);
  socket_->clearSent();
  session->onCaptureFrame(sineFrame(1).data());

  const std::vector<Datagram> sent = audioOnly(parsed(*socket_));
  ASSERT_EQ(sent.size(), 1U);
  EXPECT_EQ(sent[0].to, kStranger);
  EXPECT_EQ(sent[0].header.participantId, kParticipantHost);
  EXPECT_TRUE(sent[0].header.has(packet_flags::kTalkspurtStart));
}

// --- Receiving

TEST_F(PeerSessionTest, TheClientIgnoresOtherSources) {
  auto session = make(clientConfig());
  RemoteSender host(0);

  deliver(*session, host.next(), kStranger, 0);

  EXPECT_EQ(session->stats().foreignPackets, 1U);
  EXPECT_EQ(session->stats().packetsReceived, 0U);
  EXPECT_TRUE(events_.events().empty());
}

TEST_F(PeerSessionTest, TheHostIgnoresASecondPeer) {
  auto session = make(hostConfig());
  RemoteSender client(255);
  deliver(*session, client.next(), kStranger, 0);

  deliver(*session, client.next(), kHost, 0);

  EXPECT_EQ(session->peer(), kStranger);
  EXPECT_EQ(session->stats().foreignPackets, 1U);
}

TEST_F(PeerSessionTest, CountsMalformedDatagrams) {
  auto session = make(clientConfig());
  const std::vector<uint8_t> tooShort{0x10, 0, 0};
  std::vector<uint8_t> emptyAudio(kAudioHeaderBytes);
  emptyAudio.resize(writePacket(AudioHeader{}, nullptr, 0, emptyAudio.data(), emptyAudio.size()));

  deliver(*session, tooShort, kHost, 0);
  deliver(*session, emptyAudio, kHost, 0);

  EXPECT_EQ(session->stats().malformedPackets, 2U);
  EXPECT_FALSE(session->stats().linkUp);
}

TEST_F(PeerSessionTest, ReportsTheLinkUpOnTheFirstValidDatagram) {
  auto session = make(clientConfig());
  RemoteSender host(0);

  deliver(*session, host.next(), kHost, 10 * kMs);
  deliver(*session, host.next(), kHost, 30 * kMs);

  EXPECT_TRUE(session->stats().linkUp);
  EXPECT_EQ(events_.linkStates(), std::vector<bool>{true});
}

TEST_F(PeerSessionTest, ReportsTheLinkDownAfterTheTimeout) {
  auto session = make(clientConfig());
  deliver(*session, keepalive(KeepaliveKind::kPing, 0, 0), kHost, 1000 * kMs);

  session->tick(5900 * kMs);
  EXPECT_TRUE(session->stats().linkUp);
  session->tick(6000 * kMs);

  EXPECT_FALSE(session->stats().linkUp);
  EXPECT_EQ(events_.linkStates(), (std::vector<bool>{true, false}));
  EXPECT_EQ(session->peer(), kHost);  // the client keeps its host
}

TEST_F(PeerSessionTest, ToleratesArrivalsStampedAfterTheTick) {
  auto session = make(clientConfig());
  deliver(*session, keepalive(KeepaliveKind::kPing, 0, 0), kHost, 7000 * kMs);

  session->tick(6999 * kMs);  // the media thread read the clock first

  EXPECT_TRUE(session->stats().linkUp);
}

TEST_F(PeerSessionTest, TheHostForgetsAPeerThatWentAway) {
  auto session = make(hostConfig());
  deliver(*session, keepalive(KeepaliveKind::kPing, 0, 255), kStranger, 1000 * kMs);
  session->tick(1000 * kMs);
  session->tick(7000 * kMs);
  ASSERT_FALSE(session->peer().has_value());

  deliver(*session, keepalive(KeepaliveKind::kPing, 0, 255), kHost, 7100 * kMs);

  EXPECT_EQ(session->peer(), kHost);
  EXPECT_EQ(events_.linkStates(), (std::vector<bool>{true, false, true}));
}

// --- Keepalives and RTT

TEST_F(PeerSessionTest, TheClientPingsTheHostEverySecond) {
  auto session = make(clientConfig());
  session->tick(1000 * kMs);
  session->tick(1500 * kMs);
  session->tick(2000 * kMs);

  const std::vector<Datagram> sent = parsed(*socket_);
  ASSERT_EQ(sent.size(), 2U);
  for (const Datagram& ping : sent) {
    EXPECT_TRUE(ping.header.has(packet_flags::kKeepalive));
    EXPECT_EQ(ping.to, kHost);
  }
  const auto first = parseKeepaliveBody(sent[0].payload.data(), sent[0].payload.size());
  ASSERT_TRUE(first.has_value());
  EXPECT_EQ(first->kind, KeepaliveKind::kPing);
  EXPECT_EQ(first->originMs, 1000U);
}

TEST_F(PeerSessionTest, AnswersAPingWithAPong) {
  auto session = make(hostConfig());

  deliver(*session, keepalive(KeepaliveKind::kPing, 4242, 255), kStranger, 0);

  const std::vector<Datagram> sent = parsed(*socket_);
  ASSERT_EQ(sent.size(), 1U);
  EXPECT_EQ(sent[0].to, kStranger);
  const auto body = parseKeepaliveBody(sent[0].payload.data(), sent[0].payload.size());
  ASSERT_TRUE(body.has_value());
  EXPECT_EQ(body->kind, KeepaliveKind::kPong);
  EXPECT_EQ(body->originMs, 4242U);
}

TEST_F(PeerSessionTest, MeasuresTheRttFromAPong) {
  auto session = make(clientConfig());
  EXPECT_EQ(session->stats().rttMs, -1);

  deliver(*session, keepalive(KeepaliveKind::kPong, 1000, 0), kHost, 1040 * kMs);

  EXPECT_EQ(session->stats().rttMs, 40);
}

TEST_F(PeerSessionTest, IgnoresAnEmptyKeepaliveBody) {
  auto session = make(clientConfig());
  std::vector<uint8_t> bare(kAudioHeaderBytes);
  AudioHeader header;
  header.flags = packet_flags::kKeepalive;
  bare.resize(writePacket(header, nullptr, 0, bare.data(), bare.size()));

  deliver(*session, bare, kHost, 0);

  EXPECT_TRUE(socket_->sent().empty());
  EXPECT_TRUE(session->stats().linkUp);  // still proves the path is alive
}

// --- Echo mode

TEST_F(PeerSessionTest, EchoModeReturnsAudioToItsSender) {
  CoreConfig config = hostConfig();
  config.echoMode = true;
  auto session = make(config);
  RemoteSender client(255);
  const std::vector<uint8_t> datagram = client.next(packet_flags::kTalkspurtStart);

  deliver(*session, datagram, kStranger, 0);
  session->onCaptureFrame(sineFrame(0).data());  // the host's own microphone is not sent

  const std::vector<testing::SentDatagram> sent = socket_->sent();
  ASSERT_EQ(sent.size(), 1U);
  EXPECT_EQ(sent[0].to, kStranger);
  std::vector<uint8_t> expected = datagram;
  expected[1] = kParticipantHost;
  EXPECT_EQ(sent[0].bytes, expected);
  EXPECT_EQ(session->stats().packetsSent, 1U);
}

// --- Playout

TEST_F(PeerSessionTest, PlaysSilenceBeforeAnyAudio) {
  auto session = make(clientConfig());
  std::vector<int16_t> out(kFrame, 7);

  session->producePlayoutFrame(out.data());

  EXPECT_TRUE(std::all_of(out.begin(), out.end(), [](int16_t s) { return s == 0; }));
}

TEST_F(PeerSessionTest, DecodesTheReceivedStream) {
  auto session = make(clientConfig());
  RemoteSender host(0);
  std::vector<int16_t> out(kFrame);
  int peak = 0;
  for (int i = 0; i < 20; ++i) {
    deliver(*session, host.next(), kHost, static_cast<uint64_t>(i) * kFrameUs);
    session->producePlayoutFrame(out.data());
    for (const int16_t sample : out) {
      peak = std::max(peak, std::abs(static_cast<int>(sample)));
    }
  }

  EXPECT_GT(peak, 3000);
  EXPECT_EQ(session->stats().packetsReceived, 20U);
  EXPECT_EQ(session->stats().packetsLost, 0U);
}

TEST_F(PeerSessionTest, RebuildsAndConcealsLostFrames) {
  auto session = make(clientConfig());
  RemoteSender host(0);
  std::vector<int16_t> out(kFrame);
  for (int i = 0; i < 4; ++i) {
    deliver(*session, host.next(), kHost, 0);
  }
  host.skip();                                    // seq 4 lost: FEC from 5
  deliver(*session, host.next(), kHost, 0);
  host.skip();                                    // seq 6 and 7 lost: concealment, then FEC
  host.skip();
  deliver(*session, host.next(), kHost, 0);
  for (int i = 0; i < 9; ++i) {
    session->producePlayoutFrame(out.data());
  }

  const SessionStats stats = session->stats();
  EXPECT_EQ(stats.packetsLost, 3U);
  EXPECT_EQ(stats.fecRecovered, 2U);
  EXPECT_GE(stats.concealedFrames, 1U);
}

TEST_F(PeerSessionTest, CountsLateAndDuplicatePacketsOnce) {
  auto session = make(clientConfig());
  RemoteSender host(0);
  std::vector<int16_t> out(kFrame);
  const std::vector<uint8_t> first = host.next();
  const std::vector<uint8_t> second = host.next();
  deliver(*session, first, kHost, 0);
  deliver(*session, second, kHost, 0);
  deliver(*session, second, kHost, 0);  // duplicate
  session->producePlayoutFrame(out.data());
  session->producePlayoutFrame(out.data());
  deliver(*session, first, kHost, 0);  // late

  const SessionStats stats = session->stats();
  EXPECT_EQ(stats.packetsLate, 1U);
  EXPECT_EQ(stats.packetsReceived, 4U);
  EXPECT_EQ(stats.packetsLost, 0U);
}

TEST_F(PeerSessionTest, StartsOverWhenThePeerRestartsItsStream) {
  auto session = make(clientConfig());
  RemoteSender before(0);
  for (int i = 0; i < 100; ++i) {
    before.next();
  }
  deliver(*session, before.next(), kHost, 0);
  deliver(*session, before.next(), kHost, 0);
  std::vector<int16_t> out(kFrame);
  session->producePlayoutFrame(out.data());

  RemoteSender restarted(0);  // seq back to 0, far behind
  deliver(*session, restarted.next(packet_flags::kTalkspurtStart), kHost, 0);

  EXPECT_EQ(session->stats().packetsLost, 0U);
}

TEST_F(PeerSessionTest, CountsUndecodableFramesAndPlaysSilence) {
  auto session = make(clientConfig());
  AudioHeader header;
  const std::vector<uint8_t> invalidOpus{0xFF, 0xFF};
  std::vector<uint8_t> datagram(kMaxDatagramBytes);
  datagram.resize(writePacket(header, invalidOpus.data(), invalidOpus.size(), datagram.data(),
                              datagram.size()));
  deliver(*session, datagram, kHost, 0);
  header.seq = 1;
  datagram.resize(kMaxDatagramBytes);
  datagram.resize(writePacket(header, invalidOpus.data(), invalidOpus.size(), datagram.data(),
                              datagram.size()));
  deliver(*session, datagram, kHost, 0);
  std::vector<int16_t> out(kFrame, 7);

  session->producePlayoutFrame(out.data());
  session->producePlayoutFrame(out.data());

  EXPECT_GE(session->stats().codecErrors, 1U);
  EXPECT_TRUE(std::all_of(out.begin(), out.end(), [](int16_t s) { return s == 0; }));
}

TEST_F(PeerSessionTest, AppliesTheOutputGain) {
  auto quiet = make(clientConfig());
  auto loud = make(clientConfig());
  loud->setOutputGain(4.0F);
  RemoteSender host(0);
  std::vector<int16_t> quietOut(kFrame);
  std::vector<int16_t> loudOut(kFrame);
  int quietPeak = 0;
  int loudPeak = 0;
  for (int i = 0; i < 10; ++i) {
    const std::vector<uint8_t> datagram = host.next();
    deliver(*quiet, datagram, kHost, 0);
    deliver(*loud, datagram, kHost, 0);
    quiet->producePlayoutFrame(quietOut.data());
    loud->producePlayoutFrame(loudOut.data());
    for (int s = 0; s < kFrame; ++s) {
      quietPeak = std::max(quietPeak, std::abs(static_cast<int>(quietOut[static_cast<std::size_t>(s)])));
      loudPeak = std::max(loudPeak, std::abs(static_cast<int>(loudOut[static_cast<std::size_t>(s)])));
    }
  }

  EXPECT_GT(loudPeak, quietPeak);
  EXPECT_LE(loudPeak, 32768);  // clamped, never wraps around
  EXPECT_GE(loudPeak, 32767);
}

// --- Statistics

TEST_F(PeerSessionTest, ReportsLossPerStatisticsWindow) {
  auto session = make(clientConfig());
  RemoteSender host(0);
  session->tick(0);
  for (int i = 0; i < 10; ++i) {
    if (i % 5 == 4) {
      host.skip();
    } else {
      deliver(*session, host.next(), kHost, 0);
    }
  }
  deliver(*session, host.next(), kHost, 0);

  session->tick(500 * kMs);
  EXPECT_FLOAT_EQ(session->stats().lossPct, 0.0F);  // the window is not over yet
  session->tick(1000 * kMs);

  EXPECT_NEAR(session->stats().lossPct, 2.0F / 11.0F * 100.0F, 0.01F);
  EXPECT_GE(session->stats().jitterTargetMs, 20);
}

// --- Real-time rules

class NullSocket final : public IDatagramSocket {
 public:
  bool sendTo(const uint8_t* /*data*/, std::size_t /*size*/, const Endpoint& /*to*/) noexcept override {
    return true;
  }
  ReceiveResult receive(uint8_t* /*buffer*/, std::size_t /*capacity*/, int /*timeoutMs*/) noexcept override {
    return ReceiveResult{};
  }
  [[nodiscard]] uint16_t localPort() const noexcept override { return 1; }
};

TEST_F(PeerSessionTest, EncodesAndDecodesWithoutAllocating) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  NullSocket socket;
  Expected<std::unique_ptr<PeerSession>> created = PeerSession::create(clientConfig(), socket, events_);
  ASSERT_TRUE(created.hasValue());
  PeerSession& session = *created.value();
  RemoteSender host(0);
  deliver(session, host.next(), kHost, 0);  // the link-up event allocates; do it first
  std::vector<std::vector<uint8_t>> incoming;
  for (int i = 0; i < 20; ++i) {
    incoming.push_back(host.next());
  }
  const std::vector<int16_t> frame = sineFrame(0);
  std::vector<int16_t> out(kFrame);
  const AllocationGuard guard;

  for (const std::vector<uint8_t>& datagram : incoming) {
    session.onCaptureFrame(frame.data());
    session.onDatagram(datagram.data(), datagram.size(), kHost, 0);
    session.producePlayoutFrame(out.data());
  }

  EXPECT_EQ(guard.allocations(), 0U);
}

}  // namespace
}  // namespace voice_core
