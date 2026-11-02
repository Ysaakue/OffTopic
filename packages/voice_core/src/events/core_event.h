// Events the core reports to the UI (docs/SPEC.md: participant joined/left,
// who is talking, connection lost/restored). Phase 1 has the lifecycle and the
// link state; later phases add participant and speaking events.

#ifndef VOICE_CORE_SRC_EVENTS_CORE_EVENT_H_
#define VOICE_CORE_SRC_EVENTS_CORE_EVENT_H_

#include <cstdint>
#include <string>
#include <variant>

#include "common/status.h"
#include "net/endpoint.h"

namespace voice_core {

enum class EngineState : uint8_t { kRunning, kStopped, kFailed };

struct StateChangedEvent {
  EngineState state = EngineState::kStopped;
  Status error = Status::kOk;  // only meaningful for kFailed
};

struct LinkChangedEvent {
  bool up = false;
  Endpoint peer;
};

using CoreEvent = std::variant<StateChangedEvent, LinkChangedEvent>;

/// Event type number as declared in voice_core.h (vc_event_type).
[[nodiscard]] int32_t eventType(const CoreEvent& event) noexcept;

/// The JSON payload of an event, documented next to vc_event_type.
[[nodiscard]] std::string serializeEvent(const CoreEvent& event);

/// Receives events from the core. Implementations must be thread-safe.
class IEventSink {
 public:
  virtual ~IEventSink() = default;
  IEventSink() = default;
  IEventSink(const IEventSink&) = delete;
  IEventSink& operator=(const IEventSink&) = delete;
  IEventSink(IEventSink&&) = delete;
  IEventSink& operator=(IEventSink&&) = delete;

  virtual void emit(const CoreEvent& event) = 0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_EVENTS_CORE_EVENT_H_
