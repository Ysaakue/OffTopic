// The process-wide VoiceEngine behind the C API (one room per process).

#ifndef VOICE_CORE_SRC_API_ENGINE_REGISTRY_H_
#define VOICE_CORE_SRC_API_ENGINE_REGISTRY_H_

#include "engine/voice_engine.h"

namespace voice_core::api {

/// The engine used by every vc_* function, built on first use with the real
/// dependencies (miniaudio, POSIX sockets, steady clock).
VoiceEngine& engine();

/// Tests only (not exported): replaces the engine with one built from
/// `dependencies`, or restores the real one when it is nullptr. The previous
/// engine is stopped and destroyed.
void resetEngineForTesting(const EngineDependencies* dependencies);

}  // namespace voice_core::api

#endif  // VOICE_CORE_SRC_API_ENGINE_REGISTRY_H_
