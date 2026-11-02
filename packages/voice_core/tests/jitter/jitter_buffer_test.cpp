#include "jitter/jitter_buffer.h"

#include <gtest/gtest.h>

#include <vector>

#include "config/core_config.h"
#include "support/allocation_guard.h"

namespace voice_core {
namespace {

using testing::AllocationGuard;

constexpr uint64_t kFrameUs = 20000;
constexpr uint32_t kFrameSamples = 320;

// Each payload is one byte: the low byte of its seq, so pops are identifiable.
class JitterBufferTest : public ::testing::Test {
 protected:
  static JitterBufferParams fixedTarget(int targetMs) {
    JitterBufferParams params = JitterBufferParams::fromConfig(CoreConfig{});
    params.delay.minMs = targetMs;
    params.delay.initialMs = targetMs;
    params.delay.maxMs = targetMs;
    return params;
  }

  InsertResult insert(JitterBuffer& buffer, int seqNumber, uint8_t flags = 0,
                      uint32_t timestamp = UINT32_MAX) {
    const auto seq = static_cast<uint16_t>(seqNumber);
    const auto payload = static_cast<uint8_t>(seq & 0xFFU);
    AudioHeader header;
    header.flags = flags;
    header.seq = seq;
    header.timestamp = timestamp == UINT32_MAX ? seq * kFrameSamples : timestamp;
    nowUs_ += 1;  // arrival order; jitter tests live in target_delay_estimator_test
    return buffer.insert(header, &payload, 1, nowUs_ + seq * kFrameUs);
  }

  // Pops once; returns the seq byte for kFrame/kFecFromNext, -1 otherwise.
  static int popSeq(JitterBuffer& buffer, PlayoutKind* kind = nullptr) {
    const PlayoutDecision decision = buffer.pop();
    if (kind != nullptr) {
      *kind = decision.kind;
    }
    if (decision.kind == PlayoutKind::kFrame || decision.kind == PlayoutKind::kFecFromNext) {
      return decision.payload[0];
    }
    return -1;
  }

  uint64_t nowUs_ = 1'000'000;
};

TEST_F(JitterBufferTest, IsSilentBeforeAnyPacket) {
  JitterBuffer buffer(JitterBufferParams::fromConfig(CoreConfig{}));
  PlayoutKind kind{};

  EXPECT_EQ(popSeq(buffer, &kind), -1);
  EXPECT_EQ(kind, PlayoutKind::kSilence);
  EXPECT_FALSE(buffer.playing());
  EXPECT_EQ(buffer.stats().emptyTicks, 1U);
}

TEST_F(JitterBufferTest, UsesAPowerOfTwoCapacityCoveringTwiceTheMaximum) {
  const JitterBuffer buffer(JitterBufferParams::fromConfig(CoreConfig{}));

  EXPECT_EQ(buffer.capacityFrames(), 16U);  // 2 * 120 / 20 + 2 = 14 -> 16
}

TEST_F(JitterBufferTest, PrebuffersTheInitialTargetBeforePlaying) {
  JitterBuffer buffer(JitterBufferParams::fromConfig(CoreConfig{}));  // 40 ms = 2 frames
  PlayoutKind kind{};

  insert(buffer, 0);
  EXPECT_EQ(popSeq(buffer, &kind), -1);
  EXPECT_EQ(kind, PlayoutKind::kSilence);
  EXPECT_EQ(buffer.depthMs(), 20);

  insert(buffer, 1);
  EXPECT_EQ(popSeq(buffer), 0);
  EXPECT_TRUE(buffer.playing());
}

TEST_F(JitterBufferTest, StartsAfterWaitingTheTargetEvenIfSparse) {
  JitterBuffer buffer(fixedTarget(60));  // 3 frames

  insert(buffer, 0);
  EXPECT_EQ(popSeq(buffer), -1);
  EXPECT_EQ(popSeq(buffer), -1);
  EXPECT_EQ(popSeq(buffer), 0);  // waited 3 ticks with a single frame
}

TEST_F(JitterBufferTest, PlaysAStreamInOrder) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  std::vector<int> played;
  for (uint16_t seq = 1; seq <= 20; ++seq) {
    insert(buffer, seq);
    played.push_back(popSeq(buffer));
  }

  std::vector<int> expected;
  for (int seq = 0; seq < 20; ++seq) {
    expected.push_back(seq);
  }
  EXPECT_EQ(played, expected);
  EXPECT_EQ(buffer.stats().lost, 0U);
}

TEST_F(JitterBufferTest, ReordersWithinTheWindow) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  ASSERT_EQ(popSeq(buffer), 0);
  insert(buffer, 3);
  insert(buffer, 2);

  EXPECT_EQ(popSeq(buffer), 1);
  EXPECT_EQ(popSeq(buffer), 2);
  EXPECT_EQ(popSeq(buffer), 3);
  EXPECT_EQ(buffer.stats().lost, 0U);
}

TEST_F(JitterBufferTest, ReordersBeforePlayoutStarts) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 5);
  EXPECT_EQ(insert(buffer, 4), InsertResult::kStored);

  EXPECT_EQ(popSeq(buffer), 4);
  EXPECT_EQ(popSeq(buffer), 5);
}

TEST_F(JitterBufferTest, DropsDuplicates) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);

  EXPECT_EQ(insert(buffer, 0), InsertResult::kDuplicate);
  EXPECT_EQ(buffer.stats().duplicates, 1U);
  EXPECT_EQ(buffer.stats().stored, 1U);
}

TEST_F(JitterBufferTest, DropsAndCountsLatePackets) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  insert(buffer, 3);
  ASSERT_EQ(popSeq(buffer), 0);
  ASSERT_EQ(popSeq(buffer), 1);
  PlayoutKind kind{};
  ASSERT_EQ(popSeq(buffer, &kind), 3);  // 2 lost, rebuilt from 3's FEC
  ASSERT_EQ(kind, PlayoutKind::kFecFromNext);

  EXPECT_EQ(insert(buffer, 2), InsertResult::kLate);
  EXPECT_EQ(buffer.stats().late, 1U);
}

TEST_F(JitterBufferTest, RebuildsALostFrameFromTheNextPacketsFec) {
  JitterBuffer buffer(fixedTarget(40));
  for (const int seq : {0, 1, 3}) {
    insert(buffer, seq);
  }
  PlayoutKind kind{};

  EXPECT_EQ(popSeq(buffer), 0);
  EXPECT_EQ(popSeq(buffer), 1);
  EXPECT_EQ(popSeq(buffer, &kind), 3);
  EXPECT_EQ(kind, PlayoutKind::kFecFromNext);
  EXPECT_EQ(popSeq(buffer, &kind), 3);
  EXPECT_EQ(kind, PlayoutKind::kFrame);
  EXPECT_EQ(buffer.stats().lost, 1U);
  EXPECT_EQ(buffer.stats().fecRecovered, 1U);
}

TEST_F(JitterBufferTest, ConcealsWhenTheNextPacketIsMissingToo) {
  JitterBuffer buffer(fixedTarget(40));
  for (const int seq : {0, 1, 4}) {
    insert(buffer, seq);
  }
  PlayoutKind kind{};
  popSeq(buffer);
  popSeq(buffer);

  EXPECT_EQ(popSeq(buffer, &kind), -1);
  EXPECT_EQ(kind, PlayoutKind::kConceal);  // 2 lost, 3 missing
  EXPECT_EQ(popSeq(buffer, &kind), 4);
  EXPECT_EQ(kind, PlayoutKind::kFecFromNext);  // 3 lost, rebuilt from 4
  EXPECT_EQ(popSeq(buffer), 4);
  EXPECT_EQ(buffer.stats().lost, 2U);
  EXPECT_EQ(buffer.stats().concealed, 1U);
}

TEST_F(JitterBufferTest, CrossesTheSeqWrap) {
  JitterBuffer buffer(fixedTarget(40));
  for (const int seq : {65534, 65535, 0, 1}) {
    insert(buffer, seq, 0, 0);
  }

  EXPECT_EQ(popSeq(buffer), 65534 & 0xFF);
  EXPECT_EQ(popSeq(buffer), 65535 & 0xFF);
  EXPECT_EQ(popSeq(buffer), 0);
  EXPECT_EQ(popSeq(buffer), 1);
}

TEST_F(JitterBufferTest, WaitsThroughAnUnderflowWithoutSkipping) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);
  popSeq(buffer);
  PlayoutKind kind{};

  EXPECT_EQ(popSeq(buffer, &kind), -1);
  EXPECT_EQ(kind, PlayoutKind::kConceal);
  insert(buffer, 2);  // arrives late but nothing was skipped

  EXPECT_EQ(popSeq(buffer), 2);
  EXPECT_EQ(buffer.stats().lost, 0U);
  EXPECT_EQ(buffer.stats().late, 0U);
}

TEST_F(JitterBufferTest, StopsConcealingAfterTheLimit) {
  JitterBuffer buffer(fixedTarget(40));  // concealment limit: 100 ms = 5 frames
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);
  popSeq(buffer);
  std::vector<PlayoutKind> kinds;
  for (int i = 0; i < 7; ++i) {
    PlayoutKind kind{};
    popSeq(buffer, &kind);
    kinds.push_back(kind);
  }

  EXPECT_EQ(kinds, (std::vector<PlayoutKind>{PlayoutKind::kConceal, PlayoutKind::kConceal,
                                             PlayoutKind::kConceal, PlayoutKind::kConceal,
                                             PlayoutKind::kConceal, PlayoutKind::kSilence,
                                             PlayoutKind::kSilence}));
}

TEST_F(JitterBufferTest, NeverConcealsWithAZeroLimit) {
  JitterBufferParams params = fixedTarget(40);
  params.concealmentMaxMs = 0;
  JitterBuffer buffer(params);
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);
  popSeq(buffer);
  PlayoutKind kind{};

  popSeq(buffer, &kind);
  EXPECT_EQ(kind, PlayoutKind::kSilence);
}

TEST_F(JitterBufferTest, TreatsADtxGapAsSilenceNotLoss) {
  JitterBuffer buffer(fixedTarget(40));
  for (uint16_t seq = 0; seq < 5; ++seq) {
    insert(buffer, seq);
    popSeq(buffer);
  }
  for (int i = 0; i < 50; ++i) {  // one second of silence
    popSeq(buffer);
  }
  // Talking again: consecutive seq, timestamp 1 s later, talkspurt flag.
  insert(buffer, 5, packet_flags::kTalkspurtStart, 105 * kFrameSamples);
  EXPECT_EQ(popSeq(buffer), -1);  // re-anchors: waits for the target again
  insert(buffer, 6, 0, 106 * kFrameSamples);

  EXPECT_EQ(popSeq(buffer), 5);
  EXPECT_EQ(popSeq(buffer), 6);
  EXPECT_EQ(buffer.stats().lost, 0U);
  EXPECT_EQ(buffer.stats().late, 0U);
}

TEST_F(JitterBufferTest, SkipsFramesLostBeforeATalkspurt) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);
  popSeq(buffer);
  popSeq(buffer);  // empty

  insert(buffer, 4, packet_flags::kTalkspurtStart);  // 2 and 3 never arrived
  insert(buffer, 5);

  EXPECT_EQ(popSeq(buffer), 4);
  EXPECT_EQ(buffer.stats().lost, 0U);
}

TEST_F(JitterBufferTest, DropsFramesWhenTheDepthStaysAboveTheTarget) {
  JitterBuffer buffer(fixedTarget(40));  // 2 frames; hold 500 ms = 25 ticks
  uint16_t next = 0;
  for (; next < 6; ++next) {
    insert(buffer, next);  // a burst: 6 frames queued
  }
  for (int tick = 0; tick < 30; ++tick) {
    popSeq(buffer);
    insert(buffer, next++);
  }

  EXPECT_EQ(buffer.stats().dropped, 1U);
  EXPECT_LE(buffer.depthMs(), 100);
}

TEST_F(JitterBufferTest, InsertsAFrameWhenTheDepthStaysBelowTheTarget) {
  JitterBuffer buffer(fixedTarget(80));  // 4 frames
  uint16_t next = 0;
  for (; next < 4; ++next) {
    insert(buffer, next);
  }
  ASSERT_EQ(popSeq(buffer), 0);
  popSeq(buffer);
  popSeq(buffer);  // the sender fell behind: depth 1
  for (int tick = 0; tick < 30; ++tick) {
    insert(buffer, next++);
    popSeq(buffer);
  }

  EXPECT_EQ(buffer.stats().inserted, 1U);
  EXPECT_EQ(buffer.stats().lost, 0U);
}

TEST_F(JitterBufferTest, RestartsWhenTheSeqJumpsAhead) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);

  EXPECT_EQ(insert(buffer, 30000), InsertResult::kRestarted);
  EXPECT_FALSE(buffer.playing());
  EXPECT_EQ(buffer.stats().restarts, 1U);
  insert(buffer, 30001);
  EXPECT_EQ(popSeq(buffer), 30000 & 0xFF);
}

TEST_F(JitterBufferTest, RestartsWhenTheSeqJumpsFarBack) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 1000);
  insert(buffer, 1001);
  popSeq(buffer);

  EXPECT_EQ(insert(buffer, 10), InsertResult::kRestarted);
}

TEST_F(JitterBufferTest, RestartsOnAnOldTalkspurtStart) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 100);
  insert(buffer, 101);
  popSeq(buffer);
  popSeq(buffer);

  EXPECT_EQ(insert(buffer, 98, packet_flags::kTalkspurtStart), InsertResult::kRestarted);
}

TEST_F(JitterBufferTest, RejectsAnOversizedPayload) {
  JitterBuffer buffer(fixedTarget(40));
  const std::vector<uint8_t> payload(kMaxOpusPayloadBytes + 1);

  EXPECT_EQ(buffer.insert(AudioHeader{}, payload.data(), payload.size(), 0),
            InsertResult::kRejected);
}

TEST_F(JitterBufferTest, StoresAnEmptyPayload) {
  JitterBuffer buffer(fixedTarget(20));
  AudioHeader header;
  header.seq = 3;

  EXPECT_EQ(buffer.insert(header, nullptr, 0, 0), InsertResult::kStored);
  EXPECT_EQ(buffer.pop().size, 0U);
}

TEST_F(JitterBufferTest, ResetForgetsTheStream) {
  JitterBuffer buffer(fixedTarget(40));
  insert(buffer, 0);
  insert(buffer, 1);
  popSeq(buffer);
  buffer.reset();
  PlayoutKind kind{};

  EXPECT_EQ(popSeq(buffer, &kind), -1);
  EXPECT_EQ(kind, PlayoutKind::kSilence);
  EXPECT_EQ(buffer.depthMs(), 0);
  EXPECT_EQ(insert(buffer, 500), InsertResult::kStored);  // a fresh start, not a restart
  EXPECT_EQ(buffer.stats().restarts, 0U);
}

TEST_F(JitterBufferTest, ReportsTheAdaptiveTarget) {
  const JitterBuffer buffer(JitterBufferParams::fromConfig(CoreConfig{}));

  EXPECT_EQ(buffer.targetMs(), 40);
}

TEST_F(JitterBufferTest, DoesNotAllocateWhileRunning) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  JitterBuffer buffer(JitterBufferParams::fromConfig(CoreConfig{}));
  const AllocationGuard guard;

  for (uint16_t seq = 0; seq < 200; ++seq) {
    if (seq % 7 != 0) {
      insert(buffer, seq);
    }
    buffer.pop();
  }

  EXPECT_EQ(guard.allocations(), 0U);
}

}  // namespace
}  // namespace voice_core
