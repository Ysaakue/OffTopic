// EventDispatcher: payload ownership (one allocation per event, released by
// the callee exactly once; ASan reports any leak or double free) and the
// callback replacement guarantee.

#include "events/event_dispatcher.h"

#include <gtest/gtest.h>

#include <atomic>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace voice_core {
namespace {

std::mutex receivedMutex;
std::vector<std::pair<int32_t, std::string>> received;
std::atomic<int> calls{0};

void recordAndFree(int32_t event, char* payload) {
  {
    const std::lock_guard<std::mutex> lock(receivedMutex);
    received.emplace_back(event, payload);
  }
  ++calls;
  EventDispatcher::freePayload(payload);
}

class EventDispatcherTest : public ::testing::Test {
 protected:
  void SetUp() override {
    const std::lock_guard<std::mutex> lock(receivedMutex);
    received.clear();
    calls = 0;
  }
};

TEST_F(EventDispatcherTest, DeliversTypeAndJson) {
  EventDispatcher dispatcher;
  dispatcher.setCallback(recordAndFree);

  dispatcher.emit(StateChangedEvent{EngineState::kRunning, Status::kOk});

  ASSERT_EQ(received.size(), 1U);
  EXPECT_EQ(received[0].first, 1);
  EXPECT_EQ(received[0].second, R"({"state":"running"})");
}

TEST_F(EventDispatcherTest, DoesNothingWithoutACallback) {
  EventDispatcher dispatcher;

  dispatcher.emit(LinkChangedEvent{});

  EXPECT_EQ(calls.load(), 0);
}

TEST_F(EventDispatcherTest, StopsCallingAfterTheCallbackIsCleared) {
  EventDispatcher dispatcher;
  dispatcher.setCallback(recordAndFree);
  dispatcher.emit(LinkChangedEvent{});

  dispatcher.setCallback(nullptr);
  dispatcher.emit(LinkChangedEvent{});

  EXPECT_EQ(calls.load(), 1);
}

TEST_F(EventDispatcherTest, FreeingNullIsHarmless) { EventDispatcher::freePayload(nullptr); }

// Under ThreadSanitizer: emitting from one thread while another swaps the
// callback is race-free, and every delivered payload is freed once.
TEST_F(EventDispatcherTest, IsSafeAcrossThreads) {
  EventDispatcher dispatcher;
  std::atomic<bool> done{false};
  std::thread emitter([&] {
    for (int i = 0; i < 2000; ++i) {
      dispatcher.emit(LinkChangedEvent{i % 2 == 0, Endpoint{1, 2}});
    }
    done = true;
  });
  while (!done) {
    dispatcher.setCallback(recordAndFree);
    dispatcher.setCallback(nullptr);
  }
  emitter.join();

  const std::lock_guard<std::mutex> lock(receivedMutex);
  EXPECT_EQ(received.size(), static_cast<std::size_t>(calls.load()));
}

}  // namespace
}  // namespace voice_core
