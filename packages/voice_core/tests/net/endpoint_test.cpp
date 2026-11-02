#include "net/endpoint.h"

#include <gtest/gtest.h>

#include <string>

namespace voice_core {
namespace {

TEST(ParseIpv4Test, ParsesDottedQuads) {
  EXPECT_EQ(parseIpv4("192.168.43.1"), 0xC0A82B01U);
  EXPECT_EQ(parseIpv4("0.0.0.0"), 0U);
  EXPECT_EQ(parseIpv4("255.255.255.255"), 0xFFFFFFFFU);
  EXPECT_EQ(parseIpv4("10.0.0.007"), 0x0A000007U);
}

TEST(ParseIpv4Test, RejectsEverythingElse) {
  for (const char* text : {"", "192.168.43", "192.168.43.1.5", "192.168.43.", ".1.2.3",
                           "256.1.1.1", "1.2.3.1000", "1..2.3", "1.2.3.4 ", " 1.2.3.4", "+1.2.3.4",
                           "1.2.3.a", "a.b.c.d", "1,2,3,4", "::1"}) {
    EXPECT_FALSE(parseIpv4(text).has_value()) << '"' << text << '"';
  }
}

TEST(FormatTest, FormatsAddressesAndEndpoints) {
  EXPECT_EQ(formatIpv4(0xC0A82B01U), "192.168.43.1");
  EXPECT_EQ(formatIpv4(0), "0.0.0.0");
  EXPECT_EQ(formatEndpoint(Endpoint{0x7F000001U, 47801}), "127.0.0.1:47801");
}

TEST(FormatTest, RoundTripsWithParse) {
  const std::string text = "172.20.10.14";
  EXPECT_EQ(formatIpv4(parseIpv4(text).value()), text);
}

TEST(IsUnicastTest, AcceptsUnicast) {
  EXPECT_TRUE(isUnicast(0xC0A82B01U));  // 192.168.43.1
  EXPECT_TRUE(isUnicast(0x0A000001U));  // 10.0.0.1
  EXPECT_TRUE(isUnicast(0xDFFFFFFFU));  // 223.255.255.255: last address below multicast
  EXPECT_TRUE(isUnicast(0xF0000000U));  // 240.0.0.0: reserved, but not multicast
}

TEST(IsUnicastTest, RejectsAnyBroadcastAndMulticast) {
  EXPECT_FALSE(isUnicast(0));            // 0.0.0.0
  EXPECT_FALSE(isUnicast(0xFFFFFFFFU));  // 255.255.255.255
  EXPECT_FALSE(isUnicast(0xE0000001U));  // 224.0.0.1
  EXPECT_FALSE(isUnicast(0xEFFFFFFFU));  // 239.255.255.255
}

TEST(EndpointTest, ComparesAddressAndPort) {
  const Endpoint a{1, 2};
  EXPECT_EQ(a, (Endpoint{1, 2}));
  EXPECT_NE(a, (Endpoint{1, 3}));
  EXPECT_NE(a, (Endpoint{2, 2}));
}

}  // namespace
}  // namespace voice_core
