// IDatagramSocket contract, run against the POSIX socket (real localhost UDP,
// the only real network allowed in unit tests) and the in-memory fake.

#include <gtest/gtest.h>

#include <memory>
#include <vector>

#include "fakes/fake_network.h"
#include "net/datagram_socket.h"
#include "net/network_binder.h"
#include "net/posix_udp_socket.h"

namespace voice_core {
namespace {

constexpr uint32_t kLoopback = 0x7F000001;
constexpr int kWaitMs = 1000;
constexpr int kShortWaitMs = 10;

class PosixHarness {
 public:
  std::unique_ptr<IDatagramSocket> open() {
    Expected<std::unique_ptr<IDatagramSocket>> socket = factory_.openUdp(UdpSocketOptions{});
    EXPECT_TRUE(socket.hasValue());
    return std::move(socket).value();
  }

 private:
  NoopNetworkBinder binder_;
  PosixSocketFactory factory_{binder_};
};

class FakeHarness {
 public:
  std::unique_ptr<IDatagramSocket> open() {
    Expected<std::unique_ptr<IDatagramSocket>> socket = factory_.openUdp(UdpSocketOptions{});
    EXPECT_TRUE(socket.hasValue());
    return std::move(socket).value();
  }

 private:
  testing::FakeNetwork network_{kLoopback};
  testing::FakeSocketFactory factory_{network_};
};

template <typename Harness>
class DatagramSocketContractTest : public ::testing::Test {
 protected:
  Harness harness_;
};

using Harnesses = ::testing::Types<PosixHarness, FakeHarness>;
TYPED_TEST_SUITE(DatagramSocketContractTest, Harnesses, );  // empty name generator: clang -Wpedantic

TYPED_TEST(DatagramSocketContractTest, DeliversADatagramWithItsSource) {
  std::unique_ptr<IDatagramSocket> a = this->harness_.open();
  std::unique_ptr<IDatagramSocket> b = this->harness_.open();
  const std::vector<uint8_t> data{1, 2, 3, 4};

  ASSERT_TRUE(a->sendTo(data.data(), data.size(), Endpoint{kLoopback, b->localPort()}));
  std::vector<uint8_t> buffer(64);
  const ReceiveResult result = b->receive(buffer.data(), buffer.size(), kWaitMs);

  ASSERT_EQ(result.kind, ReceiveResult::Kind::kDatagram);
  EXPECT_EQ(result.size, data.size());
  EXPECT_EQ(std::vector<uint8_t>(buffer.begin(), buffer.begin() + 4), data);
  EXPECT_EQ(result.from, (Endpoint{kLoopback, a->localPort()}));
}

TYPED_TEST(DatagramSocketContractTest, TimesOutWithoutTraffic) {
  std::unique_ptr<IDatagramSocket> a = this->harness_.open();
  std::vector<uint8_t> buffer(16);

  EXPECT_EQ(a->receive(buffer.data(), buffer.size(), kShortWaitMs).kind,
            ReceiveResult::Kind::kTimeout);
  EXPECT_EQ(a->receive(buffer.data(), buffer.size(), 0).kind, ReceiveResult::Kind::kTimeout);
}

TYPED_TEST(DatagramSocketContractTest, KeepsDatagramBoundaries) {
  std::unique_ptr<IDatagramSocket> a = this->harness_.open();
  std::unique_ptr<IDatagramSocket> b = this->harness_.open();
  const Endpoint to{kLoopback, b->localPort()};
  const std::vector<uint8_t> first{1};
  const std::vector<uint8_t> second{2, 2};

  ASSERT_TRUE(a->sendTo(first.data(), first.size(), to));
  ASSERT_TRUE(a->sendTo(second.data(), second.size(), to));
  std::vector<uint8_t> buffer(16);

  EXPECT_EQ(b->receive(buffer.data(), buffer.size(), kWaitMs).size, 1U);
  EXPECT_EQ(b->receive(buffer.data(), buffer.size(), kWaitMs).size, 2U);
}

TYPED_TEST(DatagramSocketContractTest, GetsAnEphemeralPortWhenAskedForZero) {
  std::unique_ptr<IDatagramSocket> a = this->harness_.open();
  std::unique_ptr<IDatagramSocket> b = this->harness_.open();

  EXPECT_NE(a->localPort(), 0);
  EXPECT_NE(a->localPort(), b->localPort());
}

}  // namespace
}  // namespace voice_core
