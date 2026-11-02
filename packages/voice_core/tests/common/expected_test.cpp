#include "common/expected.h"

#include <gtest/gtest.h>

#include <memory>
#include <string>

namespace voice_core {
namespace {

TEST(ExpectedTest, HoldsAValue) {
  const Expected<std::string> value = std::string("opus");

  EXPECT_TRUE(value.hasValue());
  EXPECT_TRUE(static_cast<bool>(value));
  EXPECT_EQ(value.value(), "opus");
  EXPECT_EQ(value.status(), Status::kOk);
}

TEST(ExpectedTest, HoldsAFailure) {
  const Expected<std::string> failure = Status::kCodec;

  EXPECT_FALSE(failure.hasValue());
  EXPECT_FALSE(static_cast<bool>(failure));
  EXPECT_EQ(failure.status(), Status::kCodec);
}

TEST(ExpectedTest, CopiesAnLvalue) {
  const std::string text = "copied";
  Expected<std::string> value = text;

  value.value() += "!";

  EXPECT_EQ(value.value(), "copied!");
  EXPECT_EQ(text, "copied");
}

TEST(ExpectedTest, MovesAMoveOnlyValueOut) {
  Expected<std::unique_ptr<int>> value = std::make_unique<int>(7);

  const std::unique_ptr<int> moved = std::move(value).value();

  ASSERT_NE(moved, nullptr);
  EXPECT_EQ(*moved, 7);
}

TEST(StatusTest, MatchesTheCAbiValues) {
  EXPECT_EQ(toInt(Status::kOk), 0);
  EXPECT_EQ(toInt(Status::kInvalidArgument), -1);
  EXPECT_EQ(toInt(Status::kInternal), -6);
}

}  // namespace
}  // namespace voice_core
