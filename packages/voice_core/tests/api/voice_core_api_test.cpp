#include "voice_core.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <string>

#include "core_version.h"
#include "support/allocation_guard.h"

namespace {

using ::testing::MatchesRegex;
using voice_core::testing::AllocationGuard;

TEST(VcVersionTest, ReturnsCoreVersion) { EXPECT_STREQ(vc_version(), voice_core::kVersion); }

TEST(VcVersionTest, IsSemanticVersion) {
  EXPECT_THAT(std::string(vc_version()), MatchesRegex("[0-9]+\\.[0-9]+\\.[0-9]+"));
}

TEST(VcVersionTest, ReturnsTheSameStaticStringOnEveryCall) {
  EXPECT_EQ(vc_version(), vc_version());
}

TEST(VcVersionTest, DoesNotAllocate) {
  VC_SKIP_WITHOUT_ALLOCATION_COUNTING();
  const AllocationGuard guard;

  const char* version = vc_version();

  EXPECT_NE(version, nullptr);
  EXPECT_EQ(guard.allocations(), 0U);
}

}  // namespace
