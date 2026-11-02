// Non-blocking IPv4 UDP socket on POSIX (Linux, Android, iOS).

#ifndef VOICE_CORE_SRC_NET_POSIX_UDP_SOCKET_H_
#define VOICE_CORE_SRC_NET_POSIX_UDP_SOCKET_H_

#include <memory>

#include "net/datagram_socket.h"
#include "net/network_binder.h"

namespace voice_core {

class PosixUdpSocket final : public IDatagramSocket {
 public:
  /// Creates, binds (through `binder` first) and configures a socket.
  static Expected<std::unique_ptr<IDatagramSocket>> open(const UdpSocketOptions& options,
                                                         INetworkBinder& binder);

  ~PosixUdpSocket() override;
  PosixUdpSocket(const PosixUdpSocket&) = delete;
  PosixUdpSocket& operator=(const PosixUdpSocket&) = delete;
  PosixUdpSocket(PosixUdpSocket&&) = delete;
  PosixUdpSocket& operator=(PosixUdpSocket&&) = delete;

  bool sendTo(const uint8_t* data, std::size_t size, const Endpoint& to) noexcept override;
  ReceiveResult receive(uint8_t* buffer, std::size_t capacity, int timeoutMs) noexcept override;
  [[nodiscard]] uint16_t localPort() const noexcept override { return localPort_; }

 private:
  PosixUdpSocket(int fd, uint16_t localPort) noexcept : fd_(fd), localPort_(localPort) {}

  const int fd_;
  const uint16_t localPort_;
};

class PosixSocketFactory final : public ISocketFactory {
 public:
  explicit PosixSocketFactory(INetworkBinder& binder) noexcept : binder_(binder) {}

  Expected<std::unique_ptr<IDatagramSocket>> openUdp(const UdpSocketOptions& options) override {
    return PosixUdpSocket::open(options, binder_);
  }

 private:
  INetworkBinder& binder_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_POSIX_UDP_SOCKET_H_
