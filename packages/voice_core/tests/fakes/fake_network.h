// In-memory UDP network: sockets are identified by (address, port) and
// datagrams are delivered instantly to the matching socket. Thread-safe, so
// the engine tests can use it from their network threads.

#ifndef VOICE_CORE_TESTS_FAKES_FAKE_NETWORK_H_
#define VOICE_CORE_TESTS_FAKES_FAKE_NETWORK_H_

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "net/datagram_socket.h"

namespace voice_core::testing {

struct SentDatagram {
  std::vector<uint8_t> bytes;
  Endpoint to;
};

class FakeNetwork;

class FakeDatagramSocket final : public IDatagramSocket {
 public:
  FakeDatagramSocket(FakeNetwork& network, Endpoint local) : network_(network), local_(local) {}
  ~FakeDatagramSocket() override;
  FakeDatagramSocket(const FakeDatagramSocket&) = delete;
  FakeDatagramSocket& operator=(const FakeDatagramSocket&) = delete;
  FakeDatagramSocket(FakeDatagramSocket&&) = delete;
  FakeDatagramSocket& operator=(FakeDatagramSocket&&) = delete;

  bool sendTo(const uint8_t* data, std::size_t size, const Endpoint& to) noexcept override;
  ReceiveResult receive(uint8_t* buffer, std::size_t capacity, int timeoutMs) noexcept override;
  [[nodiscard]] uint16_t localPort() const noexcept override { return local_.port; }

  /// Queues a datagram as if it arrived from `from`.
  void deliver(const std::vector<uint8_t>& bytes, const Endpoint& from);

  /// Everything this socket sent, oldest first.
  std::vector<SentDatagram> sent() const;
  void clearSent();

  void failSends(bool fail) { failSends_ = fail; }
  void failReceives(bool fail) { failReceives_ = fail; }
  [[nodiscard]] const Endpoint& local() const { return local_; }

 private:
  struct Inbound {
    std::vector<uint8_t> bytes;
    Endpoint from;
  };

  FakeNetwork& network_;
  const Endpoint local_;
  mutable std::mutex mutex_;
  std::condition_variable arrived_;
  std::deque<Inbound> inbox_;
  std::vector<SentDatagram> sent_;
  bool failSends_ = false;
  bool failReceives_ = false;
};

class FakeNetwork {
 public:
  /// Address every socket opened through this network gets.
  explicit FakeNetwork(uint32_t address = 0x7F000001) : address_(address) {}

  std::unique_ptr<FakeDatagramSocket> open(uint16_t port) {
    const std::lock_guard<std::mutex> lock(mutex_);
    const uint16_t chosen = port != 0 ? port : nextEphemeral_++;
    return std::make_unique<FakeDatagramSocket>(*this, Endpoint{address_, chosen});
  }

  void attach(FakeDatagramSocket* socket) {
    const std::lock_guard<std::mutex> lock(mutex_);
    sockets_[key(socket->local())] = socket;
  }
  void detach(FakeDatagramSocket* socket) {
    const std::lock_guard<std::mutex> lock(mutex_);
    sockets_.erase(key(socket->local()));
  }

  /// Delivers to the socket bound to `to`, if any (otherwise the datagram is lost).
  void route(const std::vector<uint8_t>& bytes, const Endpoint& from, const Endpoint& to) {
    FakeDatagramSocket* target = nullptr;
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      const auto found = sockets_.find(key(to));
      if (found != sockets_.end()) {
        target = found->second;
      }
    }
    if (target != nullptr) {
      target->deliver(bytes, from);
    }
  }

 private:
  static uint64_t key(const Endpoint& endpoint) {
    return (static_cast<uint64_t>(endpoint.address) << 16U) | endpoint.port;
  }

  const uint32_t address_;
  std::mutex mutex_;
  uint16_t nextEphemeral_ = 50000;
  std::map<uint64_t, FakeDatagramSocket*> sockets_;
};

inline FakeDatagramSocket::~FakeDatagramSocket() { network_.detach(this); }

inline bool FakeDatagramSocket::sendTo(const uint8_t* data, std::size_t size,
                                       const Endpoint& to) noexcept {
  std::vector<uint8_t> bytes(data, data + size);
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (failSends_) {
      return false;
    }
    sent_.push_back(SentDatagram{bytes, to});
  }
  network_.route(bytes, local_, to);
  return true;
}

inline ReceiveResult FakeDatagramSocket::receive(uint8_t* buffer, std::size_t capacity,
                                                 int timeoutMs) noexcept {
  std::unique_lock<std::mutex> lock(mutex_);
  if (failReceives_) {
    return ReceiveResult{ReceiveResult::Kind::kError, 0, {}};
  }
  arrived_.wait_for(lock, std::chrono::milliseconds(timeoutMs), [this] { return !inbox_.empty(); });
  if (inbox_.empty()) {
    return ReceiveResult{ReceiveResult::Kind::kTimeout, 0, {}};
  }
  Inbound inbound = std::move(inbox_.front());
  inbox_.pop_front();
  const std::size_t size = std::min(capacity, inbound.bytes.size());
  std::memcpy(buffer, inbound.bytes.data(), size);
  return ReceiveResult{ReceiveResult::Kind::kDatagram, size, inbound.from};
}

inline void FakeDatagramSocket::deliver(const std::vector<uint8_t>& bytes, const Endpoint& from) {
  {
    const std::lock_guard<std::mutex> lock(mutex_);
    inbox_.push_back(Inbound{bytes, from});
  }
  arrived_.notify_one();
}

inline std::vector<SentDatagram> FakeDatagramSocket::sent() const {
  const std::lock_guard<std::mutex> lock(mutex_);
  return sent_;
}

inline void FakeDatagramSocket::clearSent() {
  const std::lock_guard<std::mutex> lock(mutex_);
  sent_.clear();
}

/// ISocketFactory over a FakeNetwork. Keeps a pointer to the last socket.
class FakeSocketFactory final : public ISocketFactory {
 public:
  explicit FakeSocketFactory(FakeNetwork& network) : network_(network) {}

  Expected<std::unique_ptr<IDatagramSocket>> openUdp(const UdpSocketOptions& options) override {
    ++opened_;
    lastOptions_ = options;
    if (fail_) {
      return Status::kNetwork;
    }
    std::unique_ptr<FakeDatagramSocket> socket = network_.open(options.port);
    network_.attach(socket.get());
    last_ = socket.get();
    return std::unique_ptr<IDatagramSocket>(std::move(socket));
  }

  void fail(bool value) { fail_ = value; }
  [[nodiscard]] FakeDatagramSocket* last() const { return last_; }
  [[nodiscard]] int opened() const { return opened_; }
  [[nodiscard]] const UdpSocketOptions& lastOptions() const { return lastOptions_; }

 private:
  FakeNetwork& network_;
  bool fail_ = false;
  FakeDatagramSocket* last_ = nullptr;
  int opened_ = 0;
  UdpSocketOptions lastOptions_;
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_FAKE_NETWORK_H_
