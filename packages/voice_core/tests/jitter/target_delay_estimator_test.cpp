#include "jitter/target_delay_estimator.h"

#include <gtest/gtest.h>

#include "config/core_config.h"
#include "jitter/jitter_buffer.h"

namespace voice_core {
namespace {

constexpr uint64_t kFrameUs = 20000;
constexpr uint32_t kFrameSamples = 320;
constexpr int kPacketsPerBucket = 50;  // 4000 ms window / 20 ms / 4 buckets

TargetDelayParams defaults() { return JitterBufferParams::fromConfig(CoreConfig{}).delay; }

// Feeds `count` packets starting at index `first`; `extraUs(i)` delays packet i.
template <typename Delay>
void feed(TargetDelayEstimator& estimator, uint32_t first, uint32_t count, Delay extraUs) {
  for (uint32_t i = first; i < first + count; ++i) {
    estimator.onPacket(1'000'000 + i * kFrameUs + extraUs(i), i * kFrameSamples);
  }
}

uint64_t none(uint32_t /*i*/) { return 0; }

TEST(TargetDelayEstimatorTest, StartsAtTheInitialTarget) {
  TargetDelayEstimator estimator(defaults());
  EXPECT_EQ(estimator.targetMs(), 40);

  feed(estimator, 0, kPacketsPerBucket - 1, none);
  EXPECT_EQ(estimator.targetMs(), 40);  // the first bucket is not complete yet
}

TEST(TargetDelayEstimatorTest, ShrinksToTheMinimumOnAPerfectNetwork) {
  TargetDelayEstimator estimator(defaults());
  feed(estimator, 0, kPacketsPerBucket, none);

  EXPECT_EQ(estimator.targetMs(), 20);
}

TEST(TargetDelayEstimatorTest, CoversTheSpreadPlusOneFrame) {
  TargetDelayEstimator estimator(defaults());
  // Every fourth packet is 30 ms late: two frames of spread, plus one.
  feed(estimator, 0, kPacketsPerBucket, [](uint32_t i) -> uint64_t { return i % 4 == 0 ? 30000 : 0; });

  EXPECT_EQ(estimator.targetMs(), 60);
}

TEST(TargetDelayEstimatorTest, GrowsUpToTheMaximum) {
  TargetDelayEstimator estimator(defaults());
  feed(estimator, 0, kPacketsPerBucket, [](uint32_t i) -> uint64_t { return i % 2 == 0 ? 300000 : 0; });

  EXPECT_EQ(estimator.targetMs(), 120);
}

TEST(TargetDelayEstimatorTest, ReactsToASpikeImmediately) {
  TargetDelayEstimator estimator(defaults());
  feed(estimator, 0, kPacketsPerBucket, none);
  ASSERT_EQ(estimator.targetMs(), 20);

  feed(estimator, kPacketsPerBucket, 1, [](uint32_t /*i*/) -> uint64_t { return 70000; });

  EXPECT_EQ(estimator.targetMs(), 100);  // ceil(70 / 20) = 4 frames + 1
}

TEST(TargetDelayEstimatorTest, ForgetsASpikeOnceItLeavesTheWindow) {
  TargetDelayEstimator estimator(defaults());
  feed(estimator, 0, 1, [](uint32_t /*i*/) -> uint64_t { return 70000; });
  feed(estimator, 1, kPacketsPerBucket - 1, none);
  ASSERT_EQ(estimator.targetMs(), 100);

  feed(estimator, kPacketsPerBucket, kPacketsPerBucket * TargetDelayEstimator::kBuckets, none);

  EXPECT_EQ(estimator.targetMs(), 20);
}

TEST(TargetDelayEstimatorTest, IgnoresSilenceGapsInTheTimestamps) {
  TargetDelayEstimator estimator(defaults());
  // Packets 0..24, then a 2 s DTX gap (timestamps and arrivals jump together).
  feed(estimator, 0, 25, none);
  feed(estimator, 125, 25, none);

  EXPECT_EQ(estimator.targetMs(), 20);
}

TEST(TargetDelayEstimatorTest, HandlesTheTimestampWrap) {
  TargetDelayEstimator estimator(defaults());
  const uint32_t start = 0xFFFFFFFFU - 10 * kFrameSamples + 1;
  for (uint32_t i = 0; i < kPacketsPerBucket; ++i) {
    estimator.onPacket(i * kFrameUs, start + i * kFrameSamples);
  }

  EXPECT_EQ(estimator.targetMs(), 20);
}

TEST(TargetDelayEstimatorTest, ResetReturnsToTheInitialTarget) {
  TargetDelayEstimator estimator(defaults());
  feed(estimator, 0, kPacketsPerBucket, none);
  estimator.reset();

  EXPECT_EQ(estimator.targetMs(), 40);
}

}  // namespace
}  // namespace voice_core
