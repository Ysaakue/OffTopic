#include "events/core_event.h"

#include <gtest/gtest.h>

#include "voice_core.h"

namespace voice_core {
namespace {

TEST(CoreEventTest, MapsTypesToTheCAbi) {
  EXPECT_EQ(eventType(StateChangedEvent{}), VC_EVENT_STATE_CHANGED);
  EXPECT_EQ(eventType(LinkChangedEvent{}), VC_EVENT_LINK_CHANGED);
}

TEST(CoreEventTest, SerializesStateChanges) {
  EXPECT_EQ(serializeEvent(StateChangedEvent{EngineState::kRunning, Status::kOk}),
            R"({"state":"running"})");
  EXPECT_EQ(serializeEvent(StateChangedEvent{EngineState::kStopped, Status::kOk}),
            R"({"state":"stopped"})");
  EXPECT_EQ(serializeEvent(StateChangedEvent{EngineState::kFailed, Status::kAudioDevice}),
            R"({"state":"failed","error":-3})");
}

TEST(CoreEventTest, SerializesLinkChanges) {
  EXPECT_EQ(serializeEvent(LinkChangedEvent{true, Endpoint{0xC0A82B01U, 47801}}),
            R"({"up":true,"peer":"192.168.43.1:47801"})");
  EXPECT_EQ(serializeEvent(LinkChangedEvent{false, Endpoint{0x0A000002U, 50000}}),
            R"({"up":false,"peer":"10.0.0.2:50000"})");
}

}  // namespace
}  // namespace voice_core
