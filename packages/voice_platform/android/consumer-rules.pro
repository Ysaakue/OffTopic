# libvoice_core.so registers the natives of this class by name in JNI_OnLoad
# (packages/voice_core/src/platform/android/jni_bridge.cpp). R8 must keep the
# class name and its native methods, or every core call fails in release builds.
-keep class com.isaacgeraldo.offtopic.voiceplatform.core.NativeVoiceCore {
    native <methods>;
}
