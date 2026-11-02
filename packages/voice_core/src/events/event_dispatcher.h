// Delivers events to the C callback registered with vc_set_event_callback.
//
// Payload ownership (CLAUDE.md): every payload is a NUL-terminated string
// allocated here with malloc and owned by the callee, which must release it
// with vc_free_event_payload. Without a callback nothing is allocated.
//
// The mutex guarantees that once setCallback(nullptr) returns, the previous
// callback is never invoked again (Dart closes its NativeCallable right after).
// Never used from the audio callback.

#ifndef VOICE_CORE_SRC_EVENTS_EVENT_DISPATCHER_H_
#define VOICE_CORE_SRC_EVENTS_EVENT_DISPATCHER_H_

#include <cstdint>
#include <mutex>

#include "events/core_event.h"

namespace voice_core {

using EventCallback = void (*)(int32_t event, char* payload);

class EventDispatcher final : public IEventSink {
 public:
  void setCallback(EventCallback callback);

  void emit(const CoreEvent& event) override;

  /// Releases a payload handed to the callback.
  static void freePayload(char* payload) noexcept;

 private:
  std::mutex mutex_;
  EventCallback callback_ = nullptr;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_EVENTS_EVENT_DISPATCHER_H_
