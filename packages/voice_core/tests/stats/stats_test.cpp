// InterarrivalJitter, LossTracker and RttEstimator: known sequences give the
// expected values.

#include <gtest/gtest.h>

#include <cmath>

#include "stats/interarrival_jitter.h"
#include "stats/loss_tracker.h"
#include "stats/rtt_estimator.h"

namespace voice_core {
namespace {

constexpr uint32_t kFrame = 320;   // samples per 20 ms at 16 kHz
constexpr uint64_t kFrameUs = 20000;

TEST(InterarrivalJitterTest, IsZeroForAPerfectlyPacedStream) {
  InterarrivalJitter jitter(16000);
  for (uint32_t i = 0; i < 100; ++i) {
    jitter.onPacket(1'000'000 + i * kFrameUs, i * kFrame);
  }

  EXPECT_DOUBLE_EQ(jitter.jitterMs(), 0.0);
}

TEST(InterarrivalJitterTest, FollowsRfc3550ForOneLatePacket) {
  InterarrivalJitter jitter(16000);
  jitter.onPacket(0, 0);
  jitter.onPacket(kFrameUs + 16000, kFrame);  // 16 ms late = 256 samples

  // J = 0 + (256 - 0) / 16 = 16 samples = 1 ms
  EXPECT_NEAR(jitter.jitterMs(), 1.0, 1e-9);
}

TEST(InterarrivalJitterTest, ConvergesToTheMeanDeviation) {
  InterarrivalJitter jitter(16000);
  for (uint32_t i = 0; i < 2000; ++i) {
    const uint64_t wobble = (i % 2 == 0) ? 0 : 10000;  // alternate 0 / +10 ms
    jitter.onPacket(i * kFrameUs + wobble, i * kFrame);
  }

  EXPECT_NEAR(jitter.jitterMs(), 10.0, 0.5);
}

TEST(InterarrivalJitterTest, HandlesTheTimestampWrap) {
  InterarrivalJitter jitter(16000);
  jitter.onPacket(0, 0xFFFFFFFFU - kFrame + 1);
  jitter.onPacket(kFrameUs, 1);

  EXPECT_NEAR(jitter.jitterMs(), 0.0, 0.01);
}

TEST(InterarrivalJitterTest, ResetForgetsHistory) {
  InterarrivalJitter jitter(16000);
  jitter.onPacket(0, 0);
  jitter.onPacket(100000, kFrame);
  jitter.reset();
  jitter.onPacket(5'000'000, 0);

  EXPECT_DOUBLE_EQ(jitter.jitterMs(), 0.0);
}

TEST(LossTrackerTest, StartsWithNothing) {
  LossTracker loss;

  EXPECT_EQ(loss.expected(), 0U);
  EXPECT_EQ(loss.lost(), 0U);
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 0.0F);
}

TEST(LossTrackerTest, CountsSequenceGaps) {
  LossTracker loss;
  for (const int seq : {10, 11, 13, 14, 17}) {
    loss.onPacket(static_cast<uint16_t>(seq));
  }

  EXPECT_EQ(loss.expected(), 8U);
  EXPECT_EQ(loss.received(), 5U);
  EXPECT_EQ(loss.lost(), 3U);
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 37.5F);
}

TEST(LossTrackerTest, ReportsLossPerInterval) {
  LossTracker loss;
  for (uint16_t seq = 0; seq < 10; ++seq) {
    loss.onPacket(seq);
  }
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 0.0F);

  for (uint16_t seq = 11; seq < 20; seq += 2) {  // 10, 12, 14, 16, 18 lost
    loss.onPacket(seq);
  }
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 50.0F);
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 0.0F);  // nothing new
}

TEST(LossTrackerTest, CrossesTheSeqWrap) {
  LossTracker loss;
  for (const int seq : {65534, 65535, 0, 2}) {
    loss.onPacket(static_cast<uint16_t>(seq));
  }

  EXPECT_EQ(loss.expected(), 5U);
  EXPECT_EQ(loss.lost(), 1U);
}

TEST(LossTrackerTest, ReorderedPacketsFillTheirGap) {
  LossTracker loss;
  for (const int seq : {1, 3, 2}) {
    loss.onPacket(static_cast<uint16_t>(seq));
  }

  EXPECT_EQ(loss.expected(), 3U);
  EXPECT_EQ(loss.lost(), 0U);
}

TEST(LossTrackerTest, NeverReportsNegativeLoss) {
  LossTracker loss;
  loss.onPacket(5);
  loss.onPacket(4);  // older than the base: counted as received, not expected
  loss.onPacket(5);

  EXPECT_EQ(loss.lost(), 0U);
  EXPECT_FLOAT_EQ(loss.takeIntervalLossPct(), 0.0F);
}

TEST(LossTrackerTest, ResetStartsOver) {
  LossTracker loss;
  loss.onPacket(1);
  loss.onPacket(9);
  loss.reset();
  loss.onPacket(100);

  EXPECT_EQ(loss.expected(), 1U);
  EXPECT_EQ(loss.lost(), 0U);
}

TEST(RttEstimatorTest, IsUnknownBeforeTheFirstPong) {
  const RttEstimator rtt;

  EXPECT_EQ(rtt.smoothedMs(), -1);
  EXPECT_EQ(rtt.lastMs(), -1);
}

TEST(RttEstimatorTest, TakesTheFirstSampleAsIs) {
  RttEstimator rtt;
  rtt.onPong(1040, 1000);

  EXPECT_EQ(rtt.smoothedMs(), 40);
  EXPECT_EQ(rtt.lastMs(), 40);
}

TEST(RttEstimatorTest, SmoothsLikeTcp) {
  RttEstimator rtt;
  rtt.onPong(100, 0);  // 100
  rtt.onPong(20, 0);   // 100 + (20 - 100) / 8 = 90

  EXPECT_EQ(rtt.smoothedMs(), 90);
  EXPECT_EQ(rtt.lastMs(), 20);
}

TEST(RttEstimatorTest, HandlesTheMillisecondWrap) {
  RttEstimator rtt;
  rtt.onPong(10, 0xFFFFFFF6U);  // 20 ms across the wrap

  EXPECT_EQ(rtt.smoothedMs(), 20);
}

TEST(RttEstimatorTest, IgnoresImplausibleSamples) {
  RttEstimator rtt;
  rtt.onPong(0, 1);  // "in the future": wraps to ~49 days

  EXPECT_EQ(rtt.smoothedMs(), -1);
  rtt.onPong(50, 0);
  rtt.reset();
  EXPECT_EQ(rtt.smoothedMs(), -1);
}

}  // namespace
}  // namespace voice_core
