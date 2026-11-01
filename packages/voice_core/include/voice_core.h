// Public C API of the OffTopic voice core.
//
// This header is the only contract shared by the Dart (dart:ffi) and Kotlin
// (JNI) sides. Every function is thread-safe unless stated otherwise.

#ifndef VOICE_CORE_H_
#define VOICE_CORE_H_

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define VC_API __declspec(dllexport)
#else
#define VC_API __attribute__((visibility("default")))
#endif

/// Returns the semantic version of the voice core ("MAJOR.MINOR.PATCH").
///
/// The string is static and NUL-terminated; the caller must not free it.
VC_API const char* vc_version(void);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // VOICE_CORE_H_
