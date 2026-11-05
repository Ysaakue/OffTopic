package com.isaacgeraldo.offtopic.voiceplatform.core

/**
 * The part of the C API (voice_core.h) that Kotlin owns: the session
 * lifecycle and mute. Dart reads statistics and events through FFI.
 *
 * [NativeVoiceCore] is the JNI implementation; tests use fakes.
 */
internal interface VoiceCoreBridge {
    /** vc_init: returns a [CoreResult] code. */
    fun init(config: CoreSessionConfig): Int

    /** vc_start: returns a [CoreResult] code. */
    fun start(): Int

    /** vc_stop: idempotent. */
    fun stop()

    /** vc_set_mute. */
    fun setMute(muted: Boolean)
}

/** The fields Kotlin passes to vc_init; every other value keeps the core's default. */
internal data class CoreSessionConfig(
    val role: Int,
    val hostIp: String?,
    val controlPort: Int,
    val audioPort: Int,
    val displayName: String,
    val bitrateBps: Int,
    val echoMode: Boolean,
    val talkMode: Int,
    val vadSensitivity: Int,
)

/** vc_talk_mode values. */
internal object CoreTalkMode {
    const val VOICE = 0
    const val PUSH_TO_TALK = 1
}

/** vc_vad_sensitivity values. */
internal object CoreVadSensitivity {
    const val LOW = 0
    const val MEDIUM = 1
    const val HIGH = 2
}

/** vc_role values. */
internal object CoreRole {
    const val CLIENT = 0
    const val HOST = 1
}

/** vc_result values. */
internal object CoreResult {
    const val OK = 0
    const val INVALID_ARGUMENT = -1
    const val INVALID_STATE = -2
    const val AUDIO_DEVICE = -3
    const val NETWORK = -4
    const val CODEC = -5
    const val INTERNAL = -6
}
