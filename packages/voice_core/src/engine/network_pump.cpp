#include "engine/network_pump.h"

namespace voice_core {

bool NetworkPump::runOnce(int timeoutMs) noexcept {
  const ReceiveResult result =
      socket_.receive(datagram_.bytes.data(), datagram_.bytes.size(), timeoutMs);
  switch (result.kind) {
    case ReceiveResult::Kind::kTimeout:
      return true;
    case ReceiveResult::Kind::kError:
      return false;
    case ReceiveResult::Kind::kDatagram:
      break;
  }
  datagram_.size = static_cast<uint16_t>(result.size);
  datagram_.from = result.from;
  datagram_.arrivalUs = clock_.nowUs();
  if (!inbound_.push(datagram_)) {
    dropped_.fetch_add(1, std::memory_order_relaxed);
  }
  return true;
}

}  // namespace voice_core
