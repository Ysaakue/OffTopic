// Binds every socket to a specific network before use. On Android this keeps
// the traffic on the hotspot Wi-Fi even when the system prefers mobile data
// (android_setsocknetwork, phase 4). Elsewhere it does nothing.

#ifndef VOICE_CORE_SRC_NET_NETWORK_BINDER_H_
#define VOICE_CORE_SRC_NET_NETWORK_BINDER_H_

namespace voice_core {

class INetworkBinder {
 public:
  virtual ~INetworkBinder() = default;
  INetworkBinder() = default;
  INetworkBinder(const INetworkBinder&) = delete;
  INetworkBinder& operator=(const INetworkBinder&) = delete;
  INetworkBinder(INetworkBinder&&) = delete;
  INetworkBinder& operator=(INetworkBinder&&) = delete;

  /// Called once for every new socket descriptor. False aborts the socket.
  virtual bool bindSocket(int fd) noexcept = 0;
};

class NoopNetworkBinder final : public INetworkBinder {
 public:
  bool bindSocket(int /*fd*/) noexcept override { return true; }
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_NET_NETWORK_BINDER_H_
