// JNI entry points for com.isaacgeraldo.offtopic.voiceplatform.core.NativeVoiceCore.
//
// Kotlin owns the session lifecycle (CLAUDE.md: "two entry points"), so this
// file forwards to the same C API that Dart uses. Natives are registered in
// JNI_OnLoad, which runs when Kotlin calls System.loadLibrary("voice_core");
// when Dart loads the library first, nothing here runs and nothing breaks.
//
// Device-only shell: excluded from the desktop coverage gate (CLAUDE.md).

#include <jni.h>

#include <string>

#include "voice_core.h"

namespace {

// The single place that names the Kotlin class.
constexpr char kNativeVoiceCoreClass[] = "com/isaacgeraldo/offtopic/voiceplatform/core/NativeVoiceCore";

std::string toString(JNIEnv* env, jstring text) {
  if (text == nullptr) {
    return std::string();
  }
  const char* chars = env->GetStringUTFChars(text, nullptr);
  if (chars == nullptr) {
    return std::string();
  }
  std::string copy(chars);
  env->ReleaseStringUTFChars(text, chars);
  return copy;
}

jint nativeInit(JNIEnv* env, jobject /*self*/, jint role, jstring hostIp, jint controlPort,
                jint audioPort, jstring displayName, jint bitrateBps, jboolean echoMode) {
  const std::string host = toString(env, hostIp);
  const std::string name = toString(env, displayName);
  vc_config config;
  vc_config_defaults(&config);
  config.role = role;
  config.host_ip = host.empty() ? nullptr : host.c_str();
  config.display_name = name.c_str();
  config.control_port = static_cast<uint16_t>(controlPort);
  config.audio_port = static_cast<uint16_t>(audioPort);
  config.bitrate_bps = bitrateBps;
  config.echo_mode = echoMode == JNI_TRUE ? 1 : 0;
  return vc_init(&config);
}

jint nativeStart(JNIEnv* /*env*/, jobject /*self*/) { return vc_start(); }

void nativeStop(JNIEnv* /*env*/, jobject /*self*/) { vc_stop(); }

void nativeSetMute(JNIEnv* /*env*/, jobject /*self*/, jboolean muted) {
  vc_set_mute(muted == JNI_TRUE ? 1 : 0);
}

}  // namespace

extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  jclass type = env->FindClass(kNativeVoiceCoreClass);
  if (type == nullptr) {
    env->ExceptionClear();  // loaded without the Kotlin class (e.g. Dart only)
    return JNI_VERSION_1_6;
  }
  // Must match the `external fun`s of NativeVoiceCore.kt exactly: one entry
  // too many is a NoSuchMethodError.
  const JNINativeMethod methods[] = {
      {"nativeInit", "(ILjava/lang/String;IILjava/lang/String;IZ)I",
       reinterpret_cast<void*>(nativeInit)},
      {"nativeStart", "()I", reinterpret_cast<void*>(nativeStart)},
      {"nativeStop", "()V", reinterpret_cast<void*>(nativeStop)},
      {"nativeSetMute", "(Z)V", reinterpret_cast<void*>(nativeSetMute)},
  };
  const jint registered =
      env->RegisterNatives(type, methods, static_cast<jint>(sizeof(methods) / sizeof(methods[0])));
  env->DeleteLocalRef(type);
  if (registered != JNI_OK) {
    // A pending exception would abort the process; clear it so that
    // System.loadLibrary throws UnsatisfiedLinkError, which Dart sees as an error.
    env->ExceptionClear();
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}
