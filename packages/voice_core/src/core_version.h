// Single source of truth for the voice core version.
//
// CMakeLists.txt parses kVersion from this file, so keep the declaration on a
// single line with the exact "MAJOR.MINOR.PATCH" format.

#ifndef VOICE_CORE_SRC_CORE_VERSION_H_
#define VOICE_CORE_SRC_CORE_VERSION_H_

namespace voice_core {

inline constexpr char kVersion[] = "0.1.0";

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_CORE_VERSION_H_
