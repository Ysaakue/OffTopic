#include "net/sequence.h"

#include <gtest/gtest.h>

namespace voice_core {
namespace {

TEST(SequenceTest, OrdersWithoutWrap) {
  EXPECT_TRUE(seqNewer(11, 10));
  EXPECT_FALSE(seqNewer(10, 11));
  EXPECT_FALSE(seqNewer(10, 10));
  EXPECT_EQ(seqDelta(15, 10), 5);
  EXPECT_EQ(seqDelta(10, 15), -5);
}

TEST(SequenceTest, WrapsFrom65535ToZero) {
  EXPECT_TRUE(seqNewer(0, 65535));
  EXPECT_FALSE(seqNewer(65535, 0));
  EXPECT_EQ(seqDelta(0, 65535), 1);
  EXPECT_EQ(seqDelta(2, 65534), 4);
  EXPECT_EQ(seqDelta(65534, 2), -4);
}

TEST(SequenceTest, HalfACycleApartIsNeitherNewer) {
  EXPECT_EQ(seqDelta(32768, 0), -32768);
  EXPECT_FALSE(seqNewer(32768, 0));
  EXPECT_TRUE(seqNewer(32767, 0));
}

TEST(SequenceTest, TimestampsWrapToo) {
  EXPECT_EQ(timestampDelta(160, 0xFFFFFF60U), 320);
  EXPECT_EQ(timestampDelta(0xFFFFFF60U, 160), -320);
  EXPECT_EQ(timestampDelta(640, 320), 320);
}

}  // namespace
}  // namespace voice_core
