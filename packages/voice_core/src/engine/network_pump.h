// One iteration of the network thread: wait for a datagram and queue it for
// the media thread with its arrival time. Stamping arrivals here, not in the
// media thread, keeps the jitter and RTT measurements exact.

#ifndef VOICE_CORE_SRC_ENGINE_NETWORK_PUMP_H_
#define VOICE_CORE_SRC_ENGINE_NETWORK_PUMP_H_

#include <atomic>
#include <cstdint>

#include "audio/spsc_ring_buffer.h"
#include "common/clock.h"
#include "engine/media_loop.h"
#include "net/datagram_socket.h"

namespace voice_core {

class NetworkPump {
 public:
  NetworkPump(IDatagramSocket& socket, SpscRingBuffer<InboundDatagram>& inbound,
              const IClock& clock) noexcept
      : socket_(socket), inbound_(inbound), clock_(clock) {}

  /// Waits up to `timeoutMs`. False when the socket reported an error.
  bool runOnce(int timeoutMs) noexcept;

  /// Datagrams dropped because the media thread fell behind.
  [[nodiscard]] uint32_t dropped() const noexcept { return dropped_.load(std::memory_order_relaxed); }

 private:
  IDatagramSocket& socket_;
  SpscRingBuffer<InboundDatagram>& inbound_;
  const IClock& clock_;
  InboundDatagram datagram_{};
  std::atomic<uint32_t> dropped_{0};
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_ENGINE_NETWORK_PUMP_H_
