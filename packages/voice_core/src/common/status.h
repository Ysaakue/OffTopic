// Result codes shared by the whole core. The values are part of the C ABI:
// they match vc_result in include/voice_core.h (checked in voice_core_api.cpp).

#ifndef VOICE_CORE_SRC_COMMON_STATUS_H_
#define VOICE_CORE_SRC_COMMON_STATUS_H_

namespace voice_core {

enum class Status : int {
  kOk = 0,
  kInvalidArgument = -1,
  kInvalidState = -2,
  kAudioDevice = -3,
  kNetwork = -4,
  kCodec = -5,
  kInternal = -6,
};

[[nodiscard]] constexpr int toInt(Status status) noexcept { return static_cast<int>(status); }

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_COMMON_STATUS_H_
