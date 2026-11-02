#include "audio/spsc_ring_buffer.h"

#include <gtest/gtest.h>

#include <array>
#include <cstdint>
#include <numeric>
#include <thread>
#include <vector>

#include "support/allocation_guard.h"

namespace voice_core {
namespace {

using testing::AllocationGuard;

TEST(SpscRingBufferTest, RoundsTheCapacityUpToAPowerOfTwo) {
  EXPECT_EQ(SpscRingBuffer<int>(0).capacity(), 1U);
  EXPECT_EQ(SpscRingBuffer<int>(1).capacity(), 1U);
  EXPECT_EQ(SpscRingBuffer<int>(5).capacity(), 8U);
  EXPECT_EQ(SpscRingBuffer<int>(64).capacity(), 64U);
}

TEST(SpscRingBufferTest, StartsEmpty) {
  SpscRingBuffer<int> ring(4);
  int value = 0;

  EXPECT_EQ(ring.size(), 0U);
  EXPECT_EQ(ring.freeSpace(), 4U);
  EXPECT_FALSE(ring.pop(&value));
}

TEST(SpscRingBufferTest, PushesAndPopsInOrder) {
  SpscRingBuffer<int> ring(4);
  ASSERT_TRUE(ring.push(1));
  ASSERT_TRUE(ring.push(2));
  int value = 0;

  EXPECT_EQ(ring.size(), 2U);
  ASSERT_TRUE(ring.pop(&value));
  EXPECT_EQ(value, 1);
  ASSERT_TRUE(ring.pop(&value));
  EXPECT_EQ(value, 2);
}

TEST(SpscRingBufferTest, RefusesToPushWhenFull) {
  SpscRingBuffer<int> ring(2);
  ASSERT_TRUE(ring.push(1));
  ASSERT_TRUE(ring.push(2));

  EXPECT_FALSE(ring.push(3));
  EXPECT_EQ(ring.freeSpace(), 0U);
}

TEST(SpscRingBufferTest, WritesAndReadsPartialBlocks) {
  SpscRingBuffer<int16_t> ring(8);
  const std::array<int16_t, 6> first{1, 2, 3, 4, 5, 6};
  std::array<int16_t, 8> out{};

  EXPECT_EQ(ring.write(first.data(), first.size()), 6U);
  EXPECT_EQ(ring.write(first.data(), first.size()), 2U);  // only two free slots
  EXPECT_EQ(ring.read(out.data(), 3), 3U);
  EXPECT_EQ(ring.read(out.data() + 3, 10), 5U);  // asks for more than available

  EXPECT_EQ(out, (std::array<int16_t, 8>{1, 2, 3, 4, 5, 6, 1, 2}));
  EXPECT_EQ(ring.read(out.data(), 1), 0U);
}

TEST(SpscRingBufferTest, WrapsTheIndexAround) {
  SpscRingBuffer<int> ring(4);
  std::array<int, 3> block{};
  for (int round = 0; round < 10; ++round) {
    const std::array<int, 3> values{round, round + 1, round + 2};
    ASSERT_EQ(ring.write(values.data(), values.size()), 3U);
    ASSERT_EQ(ring.read(block.data(), block.size()), 3U);
    EXPECT_EQ(block, values);
  }
}

TEST(SpscRingBufferTest, CopiesTriviallyCopyableStructs) {
  struct Sample {
    int id;
    std::array<uint8_t, 3> bytes;
  };
  SpscRingBuffer<Sample> ring(2);
  ASSERT_TRUE(ring.push(Sample{7, {1, 2, 3}}));
  Sample out{};

  ASSERT_TRUE(ring.pop(&out));
  EXPECT_EQ(out.id, 7);
  EXPECT_EQ(out.bytes[2], 3);
}

TEST(SpscRingBufferTest, DoesNotAllocateAfterConstruction) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  SpscRingBuffer<int16_t> ring(1024);
  std::vector<int16_t> block(320, 5);
  const AllocationGuard guard;

  for (int i = 0; i < 100; ++i) {
    ring.write(block.data(), block.size());
    ring.read(block.data(), block.size());
    ring.push(1);
    int16_t value = 0;
    ring.pop(&value);
  }

  EXPECT_EQ(guard.allocations(), 0U);
}

// Run under ThreadSanitizer too: one producer, one consumer, every value
// arrives exactly once and in order.
TEST(SpscRingBufferTest, StressOneProducerOneConsumer) {
  constexpr int kValues = 200000;
  SpscRingBuffer<int> ring(256);
  std::thread producer([&ring] {
    int next = 0;
    std::array<int, 7> block{};
    while (next < kValues) {
      const int count = std::min<int>(static_cast<int>(block.size()), kValues - next);
      std::iota(block.begin(), block.begin() + count, next);
      next += static_cast<int>(ring.write(block.data(), static_cast<std::size_t>(count)));
    }
  });

  int expected = 0;
  bool inOrder = true;
  std::array<int, 5> block{};
  while (expected < kValues) {
    const std::size_t got = ring.read(block.data(), block.size());
    for (std::size_t i = 0; i < got; ++i) {
      inOrder = inOrder && block[i] == expected;
      ++expected;
    }
  }
  producer.join();

  EXPECT_TRUE(inOrder);
  EXPECT_EQ(expected, kValues);
  EXPECT_EQ(ring.size(), 0U);
}

}  // namespace
}  // namespace voice_core
