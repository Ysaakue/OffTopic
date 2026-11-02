// IClock contract, run against the real clock and the fake.

#include "common/clock.h"

#include <gtest/gtest.h>

#include <memory>

#include "fakes/fake_clock.h"

namespace voice_core {
namespace {

template <typename T>
class ClockContractTest : public ::testing::Test {
 protected:
  T clock_;
};

using Clocks = ::testing::Types<SteadyClock, testing::FakeClock>;
TYPED_TEST_SUITE(ClockContractTest, Clocks, );  // empty name generator: clang -Wpedantic

TYPED_TEST(ClockContractTest, NeverGoesBackwards) {
  const uint64_t first = this->clock_.nowUs();
  const uint64_t second = this->clock_.nowUs();

  EXPECT_GE(second, first);
}

TYPED_TEST(ClockContractTest, IsAboveZero) { EXPECT_GT(this->clock_.nowUs(), 0U); }

TEST(FakeClockTest, AdvancesOnlyWhenTold) {
  testing::FakeClock clock(5000);

  EXPECT_EQ(clock.nowUs(), 5000U);
  clock.advanceMs(2);
  clock.advanceUs(3);
  EXPECT_EQ(clock.nowUs(), 7003U);
}

}  // namespace
}  // namespace voice_core
