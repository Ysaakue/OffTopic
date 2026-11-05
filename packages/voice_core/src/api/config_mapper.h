// Conversions between the C ABI structs (voice_core.h) and the C++ core.

#ifndef VOICE_CORE_SRC_API_CONFIG_MAPPER_H_
#define VOICE_CORE_SRC_API_CONFIG_MAPPER_H_

#include <cstdint>
#include <optional>

#include "common/expected.h"
#include "config/core_config.h"
#include "engine/voice_engine.h"
#include "voice_core.h"

namespace voice_core::api {

/// The exposed subset of CoreConfig's defaults (strings are null).
void fillDefaults(vc_config* out) noexcept;

/// Copies `in` over the CoreConfig defaults and validates the result.
/// kInvalidArgument when a field is out of range.
[[nodiscard]] Expected<CoreConfig> toCoreConfig(const vc_config& in);

void toVcStats(const EngineStats& in, vc_stats* out) noexcept;

/// The C enum values as C++ enums; nullopt when out of range.
[[nodiscard]] std::optional<NoiseSuppression> toNoiseSuppression(int32_t value) noexcept;
[[nodiscard]] std::optional<TalkMode> toTalkMode(int32_t value) noexcept;
[[nodiscard]] std::optional<VadSensitivity> toVadSensitivity(int32_t value) noexcept;

}  // namespace voice_core::api

#endif  // VOICE_CORE_SRC_API_CONFIG_MAPPER_H_
