#include "audio/audio_pipelines.h"

#include <gtest/gtest.h>

#include <vector>

#include "support/allocation_guard.h"

namespace voice_core {
namespace {

using testing::AllocationGuard;

TEST(CapturePipelineTest, StoresCapturedSamples) {
  SpscRingBuffer<int16_t> ring(8);
  CapturePipeline capture(ring);
  const std::vector<int16_t> input{1, 2, 3};

  capture.onInput(input.data(), input.size());

  std::vector<int16_t> out(3);
  ASSERT_EQ(ring.read(out.data(), out.size()), 3U);
  EXPECT_EQ(out, input);
  EXPECT_EQ(capture.overruns(), 0U);
}

TEST(CapturePipelineTest, CountsAnOverrunWhenTheRingIsFull) {
  SpscRingBuffer<int16_t> ring(4);
  CapturePipeline capture(ring);
  const std::vector<int16_t> input{1, 2, 3};

  capture.onInput(input.data(), input.size());
  capture.onInput(input.data(), input.size());

  EXPECT_EQ(ring.size(), 4U);
  EXPECT_EQ(capture.overruns(), 1U);
}

TEST(CapturePipelineTest, IgnoresAMissingInputBuffer) {
  SpscRingBuffer<int16_t> ring(4);
  CapturePipeline capture(ring);

  capture.onInput(nullptr, 4);

  EXPECT_EQ(ring.size(), 0U);
  EXPECT_EQ(capture.overruns(), 0U);
}

TEST(PlayoutPipelineTest, PlaysQueuedSamples) {
  SpscRingBuffer<int16_t> ring(8);
  PlayoutPipeline playout(ring);
  const std::vector<int16_t> queued{5, 6, 7};
  ring.write(queued.data(), queued.size());
  std::vector<int16_t> out(3, -1);

  playout.onOutput(out.data(), out.size());

  EXPECT_EQ(out, queued);
  EXPECT_EQ(playout.underruns(), 0U);
}

TEST(PlayoutPipelineTest, PadsAnUnderrunWithSilence) {
  SpscRingBuffer<int16_t> ring(8);
  PlayoutPipeline playout(ring);
  const std::vector<int16_t> queued{5};
  ring.write(queued.data(), queued.size());
  std::vector<int16_t> out(3, -1);

  playout.onOutput(out.data(), out.size());

  EXPECT_EQ(out, (std::vector<int16_t>{5, 0, 0}));
  EXPECT_EQ(playout.underruns(), 1U);
}

TEST(PlayoutPipelineTest, ReportsWhatWasConsumedSinceTheLastCheck) {
  SpscRingBuffer<int16_t> ring(8);
  PlayoutPipeline playout(ring);
  std::vector<int16_t> out(6);
  EXPECT_EQ(playout.takeConsumed(), 0U);

  playout.onOutput(out.data(), 4);
  playout.onOutput(out.data(), 6);

  EXPECT_EQ(playout.takeConsumed(), 10U);
  EXPECT_EQ(playout.takeConsumed(), 0U);
}

TEST(PlayoutPipelineTest, IgnoresAMissingOutputBuffer) {
  SpscRingBuffer<int16_t> ring(8);
  PlayoutPipeline playout(ring);

  playout.onOutput(nullptr, 3);

  EXPECT_EQ(playout.underruns(), 0U);
}

TEST(DuplexAudioCallbackTest, FeedsBothPipelines) {
  SpscRingBuffer<int16_t> captureRing(8);
  SpscRingBuffer<int16_t> playoutRing(8);
  CapturePipeline capture(captureRing);
  PlayoutPipeline playout(playoutRing);
  DuplexAudioCallback callback(capture, playout);
  const std::vector<int16_t> queued{9, 9};
  playoutRing.write(queued.data(), queued.size());
  const std::vector<int16_t> input{1, 2};
  std::vector<int16_t> output(2);

  callback.onAudio(input.data(), output.data(), 2);

  EXPECT_EQ(captureRing.size(), 2U);
  EXPECT_EQ(output, queued);
}

// The audio callback must never allocate (docs/SPEC.md real-time rules).
TEST(DuplexAudioCallbackTest, DoesNotAllocate) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  SpscRingBuffer<int16_t> captureRing(1024);
  SpscRingBuffer<int16_t> playoutRing(1024);
  CapturePipeline capture(captureRing);
  PlayoutPipeline playout(playoutRing);
  DuplexAudioCallback callback(capture, playout);
  std::vector<int16_t> input(160, 3);
  std::vector<int16_t> output(160);
  const AllocationGuard guard;

  for (int i = 0; i < 50; ++i) {
    callback.onAudio(input.data(), output.data(), input.size());  // overruns and underruns too
  }

  EXPECT_EQ(guard.allocations(), 0U);
}

}  // namespace
}  // namespace voice_core
