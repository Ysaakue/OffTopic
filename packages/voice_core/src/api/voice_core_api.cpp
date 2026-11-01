// C facade over the voice core. It only translates between the C ABI and the
// C++ implementation; no logic lives here.

#include "voice_core.h"

#include "core_version.h"

extern "C" {

const char* vc_version(void) { return voice_core::kVersion; }

}  // extern "C"
