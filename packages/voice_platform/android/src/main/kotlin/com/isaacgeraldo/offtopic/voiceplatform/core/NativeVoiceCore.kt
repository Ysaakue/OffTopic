package com.isaacgeraldo.offtopic.voiceplatform.core

import com.isaacgeraldo.offtopic.voiceplatform.CoverageExcluded

/**
 * JNI binding to libvoice_core.so. The natives are registered by JNI_OnLoad
 * in packages/voice_core/src/platform/android/jni_bridge.cpp, which names
 * this class: keep the package, class and method signatures in sync.
 *
 * Excluded from coverage: a device-only shell (closed exclusion list in
 * CLAUDE.md); the native library exists only inside the APK.
 */
@CoverageExcluded
internal class NativeVoiceCore : VoiceCoreBridge {
    override fun init(config: CoreSessionConfig): Int =
        nativeInit(
            config.role,
            config.hostIp,
            config.controlPort,
            config.audioPort,
            config.displayName,
            config.bitrateBps,
            config.echoMode,
            config.talkMode,
            config.vadSensitivity,
        )

    override fun start(): Int = nativeStart()

    override fun stop() = nativeStop()

    override fun setMute(muted: Boolean) = nativeSetMute(muted)

    private external fun nativeInit(
        role: Int,
        hostIp: String?,
        controlPort: Int,
        audioPort: Int,
        displayName: String,
        bitrateBps: Int,
        echoMode: Boolean,
        talkMode: Int,
        vadSensitivity: Int,
    ): Int

    private external fun nativeStart(): Int

    private external fun nativeStop()

    private external fun nativeSetMute(muted: Boolean)

    private companion object {
        init {
            System.loadLibrary("voice_core")
        }
    }
}
