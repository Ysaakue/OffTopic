#include "events/event_dispatcher.h"

#include <cstdlib>
#include <cstring>
#include <string>

namespace voice_core {

void EventDispatcher::setCallback(EventCallback callback) {
  const std::lock_guard<std::mutex> lock(mutex_);
  callback_ = callback;
}

void EventDispatcher::emit(const CoreEvent& event) {
  const std::lock_guard<std::mutex> lock(mutex_);
  if (callback_ == nullptr) {
    return;
  }
  const std::string json = serializeEvent(event);
  // NOLINTNEXTLINE(cppcoreguidelines-no-malloc): released by vc_free_event_payload (free)
  auto* payload = static_cast<char*>(std::malloc(json.size() + 1));
  if (payload == nullptr) {  // GCOVR_EXCL_BR_LINE: malloc only fails when out of memory
    return;                  // GCOVR_EXCL_LINE: the event is dropped
  }
  std::memcpy(payload, json.c_str(), json.size() + 1);
  callback_(eventType(event), payload);
}

void EventDispatcher::freePayload(char* payload) noexcept {
  std::free(payload);  // NOLINT(cppcoreguidelines-no-malloc): pairs with emit()
}

}  // namespace voice_core
