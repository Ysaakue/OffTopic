#include "events/core_event.h"

namespace voice_core {
namespace {

// Must match vc_event_type in voice_core.h (checked in voice_core_api.cpp).
constexpr int32_t kStateChangedType = 1;
constexpr int32_t kLinkChangedType = 2;

const char* stateName(EngineState state) noexcept {
  switch (state) {
    case EngineState::kRunning:
      return "running";
    case EngineState::kStopped:
      return "stopped";
    case EngineState::kFailed:
      return "failed";
  }
  return "stopped";  // GCOVR_EXCL_LINE: unreachable, every enumerator is handled above
}

struct TypeVisitor {
  int32_t operator()(const StateChangedEvent& /*event*/) const noexcept {
    return kStateChangedType;
  }
  int32_t operator()(const LinkChangedEvent& /*event*/) const noexcept { return kLinkChangedType; }
};

struct JsonVisitor {
  std::string operator()(const StateChangedEvent& event) const {
    std::string json = R"({"state":")" + std::string(stateName(event.state)) + '"';
    if (event.state == EngineState::kFailed) {
      json += R"(,"error":)" + std::to_string(toInt(event.error));
    }
    return json + '}';
  }
  std::string operator()(const LinkChangedEvent& event) const {
    return std::string(R"({"up":)") + (event.up ? "true" : "false") + R"(,"peer":")" +
           formatEndpoint(event.peer) + R"("})";
  }
};

}  // namespace

int32_t eventType(const CoreEvent& event) noexcept { return std::visit(TypeVisitor{}, event); }

std::string serializeEvent(const CoreEvent& event) { return std::visit(JsonVisitor{}, event); }

}  // namespace voice_core
