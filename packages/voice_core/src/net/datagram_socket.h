// UDP socket abstraction. The real implementation is PosixUdpSocket; tests
// use an in-memory fake (tests/fakes/fake_network.h).

#ifndef VOICE_CORE_SRC_NET_DATAGRAM_SOCKET_H_
#define VOICE_CORE_SRC_NET_DATAGRAM_SOCKET_H_

#include <cstddef>
#include <cstdint>
#include <memory>

#include "common/expected.h"
#include "net/endpoint.h"

namespace voice_core {

struct ReceiveResult {
  enum class Kind : uint8_t { kDatagram, kTimeout, kError };
  Kind kind = Kind::kTimeout;
  std::size_t size = 0;  // valid for kDatagram
  Endpoint from;         // valid for kDatagram
};

class IDatagramSocket {
 public:
  virtual ~IDatagramSocket() = default;
  IDatagramSocket() = default;
  IDatagramSocket(const IDatagramSocket&) = delete;
  IDatagramSocket& operator=(const IDatagramSocket&) = delete;
  IDatagramSocket(IDatagramSocket&&) = delete;
  IDatagramSocket& operator=(IDatagramSocket&&) = delete;

  /// Sends one datagram without blocking. False when it could not be queued.
  virtual bool sendTo(const uint8_t* data, std::size_t size, const Endpoint& to) noexcept = 0;

  /// Waits up to `timeoutMs` for one datagram (truncated to `capacity`).
  virtual ReceiveResult receive(uint8_t* buffer, std::size_t capacity, int timeoutMs) noexcept = 0;

  [[nodiscard]] virtual uint16_t localPort() const noexcept = 0;
};

struct UdpSocketOptions {
  uint16_t port = 0;  // 0 = ephemeral
  int dscp = 0;       // DiffServ code point for outgoing packets
};

class ISocketFactory {
 public:
  virtual ~ISocketFactory() = default;
  ISocketFactory() = default;
  ISocketFactory(const ISocketFactory&) = delete;
  ISocketFactory& operator=(const ISocketFactory&) = delete;
  ISocketFactory(ISocketFactory&&) = delete;
  ISocketFactory& operator=(ISocketFactory&&) = delete;

  /// Opens a UDP socket bound to INADDR_ANY:port. kNetwork on failure.
  virtual Expected<std::unique_ptr<IDatagramSocket>> openUdp(const UdpSocketOptions& options) = 0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_DATAGRAM_SOCKET_H_
