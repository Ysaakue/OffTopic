// C facade over the voice core. It only translates between the C ABI and the
// C++ implementation; no logic lives here. No exception crosses this boundary.

#include "voice_core.h"

#include <algorithm>
#include <cmath>

#include "api/config_mapper.h"
#include "api/engine_registry.h"
#include "common/status.h"
#include "core_version.h"
#include "events/event_dispatcher.h"

namespace {

using voice_core::Status;
using voice_core::toInt;
using voice_core::api::engine;

static_assert(VC_OK == toInt(Status::kOk));
static_assert(VC_ERR_INVALID_ARGUMENT == toInt(Status::kInvalidArgument));
static_assert(VC_ERR_INVALID_STATE == toInt(Status::kInvalidState));
static_assert(VC_ERR_AUDIO_DEVICE == toInt(Status::kAudioDevice));
static_assert(VC_ERR_NETWORK == toInt(Status::kNetwork));
static_assert(VC_ERR_CODEC == toInt(Status::kCodec));
static_assert(VC_ERR_INTERNAL == toInt(Status::kInternal));

constexpr float kMaxOutputGain = 4.0F;

}  // namespace

extern "C" {

const char* vc_version(void) { return voice_core::kVersion; }

void vc_config_defaults(vc_config* out) {
  if (out != nullptr) {
    voice_core::api::fillDefaults(out);
  }
}

int32_t vc_init(const vc_config* config) {
  if (config == nullptr) {
    return VC_ERR_INVALID_ARGUMENT;
  }
  try {
    voice_core::Expected<voice_core::CoreConfig> core = voice_core::api::toCoreConfig(*config);
    if (!core) {
      return toInt(core.status());
    }
    return toInt(engine().init(core.value()));
  } catch (...) {           // GCOVR_EXCL_LINE: allocation failure only
    return VC_ERR_INTERNAL;  // GCOVR_EXCL_LINE
  }
}

int32_t vc_start(void) {
  try {
    return toInt(engine().start());
  } catch (...) {           // GCOVR_EXCL_LINE: allocation or thread creation failure only
    return VC_ERR_INTERNAL;  // GCOVR_EXCL_LINE
  }
}

void vc_stop(void) { engine().stop(); }

void vc_set_mute(int32_t muted) { engine().setMuted(muted != 0); }

void vc_set_output_gain(float gain) {
  if (std::isfinite(gain)) {
    engine().setOutputGain(std::clamp(gain, 0.0F, kMaxOutputGain));
  }
}

int32_t vc_get_stats(vc_stats* out) {
  if (out == nullptr) {
    return VC_ERR_INVALID_ARGUMENT;
  }
  voice_core::EngineStats stats;
  if (!engine().readStats(&stats)) {
    *out = vc_stats{};
    return VC_ERR_INVALID_STATE;
  }
  voice_core::api::toVcStats(stats, out);
  return VC_OK;
}

void vc_set_event_callback(vc_event_callback callback) { engine().events().setCallback(callback); }

void vc_free_event_payload(char* payload) { voice_core::EventDispatcher::freePayload(payload); }

}  // extern "C"
