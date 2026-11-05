// IEventSink that records every event for assertions.

#ifndef VOICE_CORE_TESTS_FAKES_RECORDING_EVENT_SINK_H_
#define VOICE_CORE_TESTS_FAKES_RECORDING_EVENT_SINK_H_

#include <mutex>
#include <vector>

#include "events/core_event.h"

namespace voice_core::testing {

class RecordingEventSink final : public IEventSink {
 public:
  void emit(const CoreEvent& event) override {
    const std::lock_guard<std::mutex> lock(mutex_);
    events_.push_back(event);
  }

  std::vector<CoreEvent> events() const {
    const std::lock_guard<std::mutex> lock(mutex_);
    return events_;
  }

  /// The link events, in order (true = up).
  std::vector<bool> linkStates() const {
    std::vector<bool> states;
    for (const CoreEvent& event : events()) {
      if (const auto* link = std::get_if<LinkChangedEvent>(&event)) {
        states.push_back(link->up);
      }
    }
    return states;
  }

  /// The talking events, in order (true = the microphone is sent).
  std::vector<bool> talkingStates() const {
    std::vector<bool> states;
    for (const CoreEvent& event : events()) {
      if (const auto* talking = std::get_if<TalkingChangedEvent>(&event)) {
        states.push_back(talking->talking);
      }
    }
    return states;
  }

 private:
  mutable std::mutex mutex_;
  std::vector<CoreEvent> events_;
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_RECORDING_EVENT_SINK_H_
