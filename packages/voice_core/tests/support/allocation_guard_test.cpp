#include "support/allocation_guard.h"

#include <gtest/gtest.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <new>
#include <thread>
#include <vector>

namespace voice_core::testing {
namespace {

TEST(AllocationGuardTest, StartsAtZero) {
  const AllocationGuard guard;

  EXPECT_EQ(guard.allocations(), 0U);
}

TEST(AllocationGuardTest, CountsScalarAllocation) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const auto value = std::make_unique<int>(42);

  EXPECT_EQ(guard.allocations(), 1U);
  EXPECT_EQ(*value, 42);
}

TEST(AllocationGuardTest, CountsContainerAllocation) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const std::vector<int> values(16, 7);

  EXPECT_GE(guard.allocations(), 1U);
  EXPECT_EQ(values.size(), 16U);
}

TEST(AllocationGuardTest, CountsArrayAllocation) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const auto values = std::make_unique<int[]>(8);

  EXPECT_EQ(guard.allocations(), 1U);
  EXPECT_EQ(values[0], 0);
}

TEST(AllocationGuardTest, CountsNoThrowAllocation) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const std::unique_ptr<int> value(new (std::nothrow) int(7));

  EXPECT_EQ(guard.allocations(), 1U);
  ASSERT_NE(value, nullptr);
  EXPECT_EQ(*value, 7);
}

TEST(AllocationGuardTest, CountsOverAlignedAllocation) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  struct alignas(64) CacheLine {
    std::uint8_t bytes[64];
  };
  const AllocationGuard guard;

  const auto line = std::make_unique<CacheLine>();

  EXPECT_EQ(guard.allocations(), 1U);
  EXPECT_EQ(reinterpret_cast<std::uintptr_t>(line.get()) % alignof(CacheLine), 0U);
}

TEST(AllocationGuardTest, IgnoresAllocationsFromOtherThreads) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  std::atomic<int> stage{0};
  std::thread worker([&stage] {
    while (stage.load() != 1) {
      std::this_thread::yield();
    }
    const auto value = std::make_unique<int>(1);
    stage.store(value ? 2 : 3);
  });

  std::size_t counted = 0;
  {
    const AllocationGuard guard;
    stage.store(1);
    while (stage.load() == 1) {
      std::this_thread::yield();
    }
    counted = guard.allocations();
  }
  worker.join();

  EXPECT_EQ(stage.load(), 2);
  EXPECT_EQ(counted, 0U);
}

}  // namespace
}  // namespace voice_core::testing
