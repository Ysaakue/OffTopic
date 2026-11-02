// Lifecycle owner of the core: init/start/stop, the audio device, the socket
// and the two threads (media and network). Every public method is
// thread-safe; Kotlin (JNI) and Dart (FFI) call it concurrently.
//
// Threads while running:
//   audio callback (device) -> CapturePipeline / PlayoutPipeline (rings only)
//   media thread            -> MediaLoop::runOnce + stats publication
//   network thread          -> NetworkPump::runOnce (receive + timestamp)

#ifndef VOICE_CORE_SRC_ENGINE_VOICE_ENGINE_H_
#define VOICE_CORE_SRC_ENGINE_VOICE_ENGINE_H_

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>

#include "audio/audio_device.h"
#include "common/clock.h"
#include "common/status.h"
#include "config/core_config.h"
#include "events/event_dispatcher.h"
#include "net/datagram_socket.h"
#include "session/peer_session.h"

namespace voice_core {

struct EngineDependencies {
  IAudioDeviceFactory& audio;
  ISocketFactory& sockets;
  const IClock& clock;
};

struct EngineStats {
  SessionStats session;
  uint32_t playoutUnderruns = 0;
  uint32_t captureOverruns = 0;
  uint32_t inboundDropped = 0;
};

class VoiceEngine {
 public:
  explicit VoiceEngine(EngineDependencies dependencies) noexcept;
  ~VoiceEngine();
  VoiceEngine(const VoiceEngine&) = delete;
  VoiceEngine& operator=(const VoiceEngine&) = delete;
  VoiceEngine(VoiceEngine&&) = delete;
  VoiceEngine& operator=(VoiceEngine&&) = delete;

  /// Stores a validated configuration. kInvalidState while running,
  /// kInvalidArgument when `config` is invalid.
  Status init(const CoreConfig& config);

  /// Opens the socket and the audio device and starts the threads.
  /// kInvalidState without init or when already running.
  Status start();

  /// Stops everything. Idempotent.
  void stop();

  void setMuted(bool muted) noexcept { muted_.store(muted, std::memory_order_relaxed); }
  void setOutputGain(float gain) noexcept { outputGain_.store(gain, std::memory_order_relaxed); }

  /// Latest statistics; false (and `out` untouched) when not running.
  bool readStats(EngineStats* out) const;

  [[nodiscard]] bool running() const;

  [[nodiscard]] EventDispatcher& events() noexcept { return events_; }

 private:
  struct Running;

  Status startLocked(const CoreConfig& config);
  void stopLocked();
  void mediaThread(Running& running);
  void networkThread(Running& running) const;
  void publishStats(const Running& running);

  const EngineDependencies dependencies_;
  mutable std::mutex lifecycleMutex_;
  std::optional<CoreConfig> config_;
  std::unique_ptr<Running> running_;

  std::atomic<bool> muted_{false};
  std::atomic<float> outputGain_{1.0F};
  EventDispatcher events_;

  mutable std::mutex statsMutex_;
  EngineStats stats_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_ENGINE_VOICE_ENGINE_H_
