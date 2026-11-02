// PosixUdpSocket specifics on localhost: binding, the network binder hook and
// failures. The shared behaviour is in datagram_socket_contract_test.cpp.

#include "net/posix_udp_socket.h"

#include <gtest/gtest.h>

#include <memory>
#include <vector>

#include "fakes/spy_network_binder.h"

namespace voice_core {
namespace {

using testing::SpyNetworkBinder;

constexpr uint32_t kLoopback = 0x7F000001;

TEST(PosixUdpSocketTest, CallsTheNetworkBinderForEverySocket) {
  SpyNetworkBinder binder;
  PosixSocketFactory factory(binder);

  auto first = factory.openUdp(UdpSocketOptions{});
  auto second = factory.openUdp(UdpSocketOptions{});

  ASSERT_TRUE(first.hasValue());
  ASSERT_TRUE(second.hasValue());
  ASSERT_EQ(binder.descriptors.size(), 2U);
  EXPECT_GE(binder.descriptors[0], 0);
  EXPECT_NE(binder.descriptors[0], binder.descriptors[1]);
}

TEST(PosixUdpSocketTest, FailsWhenTheBinderRefuses) {
  SpyNetworkBinder binder;
  binder.result = false;

  const auto socket = PosixUdpSocket::open(UdpSocketOptions{}, binder);

  EXPECT_EQ(socket.status(), Status::kNetwork);
}

TEST(PosixUdpSocketTest, BindsTheRequestedPortAndRefusesItTwice) {
  NoopNetworkBinder binder;
  auto first = PosixUdpSocket::open(UdpSocketOptions{}, binder);
  ASSERT_TRUE(first.hasValue());
  const uint16_t port = first.value()->localPort();
  first = Status::kInvalidState;  // closes the probe socket, freeing the port

  UdpSocketOptions options;
  options.port = port;
  options.dscp = 46;
  auto bound = PosixUdpSocket::open(options, binder);
  ASSERT_TRUE(bound.hasValue());
  EXPECT_EQ(bound.value()->localPort(), port);

  const auto duplicate = PosixUdpSocket::open(options, binder);
  EXPECT_EQ(duplicate.status(), Status::kNetwork);
}

TEST(PosixUdpSocketTest, ClosingFreesThePort) {
  NoopNetworkBinder binder;
  UdpSocketOptions options;
  {
    auto socket = PosixUdpSocket::open(UdpSocketOptions{}, binder);
    ASSERT_TRUE(socket.hasValue());
    options.port = socket.value()->localPort();
  }

  EXPECT_TRUE(PosixUdpSocket::open(options, binder).hasValue());
}

TEST(PosixUdpSocketTest, ReportsAFailedSend) {
  NoopNetworkBinder binder;
  auto socket = PosixUdpSocket::open(UdpSocketOptions{}, binder);
  ASSERT_TRUE(socket.hasValue());
  const std::vector<uint8_t> data{1};

  EXPECT_FALSE(socket.value()->sendTo(data.data(), data.size(), Endpoint{0, 0}));
}

TEST(PosixUdpSocketTest, TruncatesToTheBufferCapacity) {
  NoopNetworkBinder binder;
  auto a = PosixUdpSocket::open(UdpSocketOptions{}, binder);
  auto b = PosixUdpSocket::open(UdpSocketOptions{}, binder);
  ASSERT_TRUE(a.hasValue() && b.hasValue());
  const std::vector<uint8_t> data{1, 2, 3, 4, 5, 6};

  ASSERT_TRUE(
      a.value()->sendTo(data.data(), data.size(), Endpoint{kLoopback, b.value()->localPort()}));
  std::vector<uint8_t> buffer(4);
  const ReceiveResult result = b.value()->receive(buffer.data(), buffer.size(), 1000);

  ASSERT_EQ(result.kind, ReceiveResult::Kind::kDatagram);
  EXPECT_EQ(result.size, 4U);
}

}  // namespace
}  // namespace voice_core
