#include "engine/media_loop.h"

#include <gtest/gtest.h>

#include <cmath>
#include <memory>
#include <vector>

#include "fakes/fake_network.h"
#include "fakes/recording_event_sink.h"

namespace voice_core {
namespace {

using testing::FakeNetwork;
using testing::RecordingEventSink;

constexpr uint32_t kLoopback = 0x7F000001;
constexpr std::size_t kFrame = 320;

class MediaLoopTest : public ::testing::Test {
 protected:
  MediaLoopTest() {
    config_.hostIp = "127.0.0.1";
    config_.displayName = "Ana";
    auto created = PeerSession::create(config_, *socket_, events_);
    session_ = std::move(created).value();
    loop_ = std::make_unique<MediaLoop>(*session_, capture_, playout_, device_, inbound_, config_);
  }

  std::size_t audioSent() const {
    std::size_t count = 0;
    for (const testing::SentDatagram& sent : socket_->sent()) {
      count += (sent.bytes[0] & packet_flags::kKeepalive) == 0 ? 1U : 0U;
    }
    return count;
  }

  CoreConfig config_;
  FakeNetwork network_{kLoopback};
  std::unique_ptr<testing::FakeDatagramSocket> socket_ = network_.open(0);
  RecordingEventSink events_;
  std::unique_ptr<PeerSession> session_;
  SpscRingBuffer<int16_t> capture_{kFrame * 8};
  SpscRingBuffer<int16_t> playout_{kFrame * 16};
  PlayoutPipeline device_{playout_};
  SpscRingBuffer<InboundDatagram> inbound_{8};
  std::unique_ptr<MediaLoop> loop_;
};

TEST_F(MediaLoopTest, EncodesEveryCompleteCapturedFrame) {
  std::vector<int16_t> samples(kFrame * 2 + 100);
  for (std::size_t i = 0; i < samples.size(); ++i) {
    samples[i] = static_cast<int16_t>(std::lround(8000.0 * std::sin(static_cast<double>(i) * 0.1)));
  }
  capture_.write(samples.data(), samples.size());

  loop_->runOnce(0);

  EXPECT_EQ(audioSent(), 2U);
  EXPECT_EQ(capture_.size(), 100U);  // the partial frame waits for the next run
}

TEST_F(MediaLoopTest, KeepsThePlayoutRingAtItsTarget) {
  loop_->runOnce(0);

  EXPECT_GE(playout_.size(), kFrame);  // playoutBufferMs = 20 ms = one frame
  EXPECT_LT(playout_.size(), kFrame * 2);

  loop_->runOnce(20000);  // nothing consumed: nothing more decoded
  EXPECT_LT(playout_.size(), kFrame * 2);
}

TEST_F(MediaLoopTest, KeepsAWholeDeviceBurstQueued) {
  // The device drains 60 ms in three back-to-back callbacks (an AAudio burst).
  std::vector<int16_t> block(kFrame / 2);
  const auto burst = [&] {
    for (int i = 0; i < 6; ++i) {
      device_.onOutput(block.data(), block.size());
    }
  };
  loop_->runOnce(0);
  burst();  // underruns once: the loop learns the burst size

  loop_->runOnce(20000);
  EXPECT_GE(playout_.size(), kFrame * 3);

  const uint32_t underruns = device_.underruns();
  burst();
  EXPECT_EQ(device_.underruns(), underruns);
}

TEST_F(MediaLoopTest, NeverQueuesMoreThanTheRingHolds) {
  std::vector<int16_t> huge(kFrame * 64);
  device_.onOutput(huge.data(), huge.size());
  loop_->runOnce(0);  // learns the burst

  loop_->runOnce(0);

  EXPECT_LE(playout_.size(), playout_.capacity());
  EXPECT_GE(playout_.size(), playout_.capacity() - kFrame);
}

TEST_F(MediaLoopTest, HandsQueuedDatagramsToTheSession) {
  InboundDatagram datagram{};
  AudioHeader header;
  header.flags = packet_flags::kKeepalive;
  datagram.size = static_cast<uint16_t>(
      writePacket(header, nullptr, 0, datagram.bytes.data(), datagram.bytes.size()));
  datagram.from = Endpoint{kLoopback, 47801};
  datagram.arrivalUs = 5;
  inbound_.push(datagram);
  inbound_.push(datagram);

  loop_->runOnce(10);

  EXPECT_EQ(inbound_.size(), 0U);
  EXPECT_TRUE(session_->stats().linkUp);
}

TEST_F(MediaLoopTest, RunsTheSessionTimers) {
  loop_->runOnce(1'000'000);

  ASSERT_EQ(socket_->sent().size(), 1U);  // the first keepalive
  EXPECT_NE(socket_->sent()[0].bytes[0] & packet_flags::kKeepalive, 0);
}

}  // namespace
}  // namespace voice_core
