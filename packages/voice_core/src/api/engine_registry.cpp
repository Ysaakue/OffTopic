#include "api/engine_registry.h"

#include <memory>
#include <mutex>

#include "audio/miniaudio_device.h"
#include "common/clock.h"
#include "net/network_binder.h"
#include "net/posix_udp_socket.h"

namespace voice_core::api {
namespace {

struct RealDependencies {
  SteadyClock clock;
  NoopNetworkBinder binder;  // the Android binder arrives with WifiBinder (phase 4)
  PosixSocketFactory sockets{binder};
  MiniaudioDeviceFactory audio;

  EngineDependencies view() noexcept { return EngineDependencies{audio, sockets, clock}; }
};

struct Registry {
  // Declared first so it is destroyed last, after the engine that uses it.
  RealDependencies real;
  std::mutex mutex;
  std::unique_ptr<VoiceEngine> engine;
};

Registry& registry() {
  static Registry instance;
  return instance;
}

}  // namespace

VoiceEngine& engine() {
  Registry& state = registry();
  const std::lock_guard<std::mutex> lock(state.mutex);
  if (!state.engine) {
    state.engine = std::make_unique<VoiceEngine>(state.real.view());
  }
  return *state.engine;
}

void resetEngineForTesting(const EngineDependencies* dependencies) {
  Registry& state = registry();
  const std::lock_guard<std::mutex> lock(state.mutex);
  state.engine.reset();
  if (dependencies != nullptr) {
    state.engine = std::make_unique<VoiceEngine>(*dependencies);
  }
}

}  // namespace voice_core::api
