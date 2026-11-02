#include "engine/network_pump.h"

#include <gtest/gtest.h>

#include <memory>
#include <vector>

#include "fakes/fake_clock.h"
#include "fakes/fake_network.h"

namespace voice_core {
namespace {

using testing::FakeClock;
using testing::FakeNetwork;

constexpr uint32_t kLoopback = 0x7F000001;

class NetworkPumpTest : public ::testing::Test {
 protected:
  FakeNetwork network_{kLoopback};
  std::unique_ptr<testing::FakeDatagramSocket> socket_ = network_.open(47801);
  SpscRingBuffer<InboundDatagram> inbound_{2};
  FakeClock clock_{123456};
  NetworkPump pump_{*socket_, inbound_, clock_};
};

TEST_F(NetworkPumpTest, QueuesADatagramWithItsArrivalTime) {
  const Endpoint from{kLoopback, 50000};
  socket_->deliver({1, 2, 3}, from);

  ASSERT_TRUE(pump_.runOnce(0));

  InboundDatagram datagram{};
  ASSERT_TRUE(inbound_.pop(&datagram));
  EXPECT_EQ(datagram.size, 3U);
  EXPECT_EQ(datagram.bytes[2], 3);
  EXPECT_EQ(datagram.from, from);
  EXPECT_EQ(datagram.arrivalUs, 123456U);
}

TEST_F(NetworkPumpTest, QueuesNothingOnTimeout) {
  EXPECT_TRUE(pump_.runOnce(0));
  EXPECT_EQ(inbound_.size(), 0U);
}

TEST_F(NetworkPumpTest, ReportsSocketErrors) {
  socket_->failReceives(true);

  EXPECT_FALSE(pump_.runOnce(0));
}

TEST_F(NetworkPumpTest, DropsAndCountsWhenTheMediaThreadFallsBehind) {
  for (int i = 0; i < 3; ++i) {
    socket_->deliver({1}, Endpoint{kLoopback, 50000});
    ASSERT_TRUE(pump_.runOnce(0));
  }

  EXPECT_EQ(inbound_.size(), 2U);
  EXPECT_EQ(pump_.dropped(), 1U);
}

}  // namespace
}  // namespace voice_core
