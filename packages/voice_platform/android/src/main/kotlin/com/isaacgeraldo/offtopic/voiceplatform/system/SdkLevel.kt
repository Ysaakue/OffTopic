package com.isaacgeraldo.offtopic.voiceplatform.system

import android.os.Build

/**
 * Android API level of the running device.
 *
 * Injected instead of reading [Build.VERSION.SDK_INT] directly, so that every
 * version-dependent branch can be unit tested on any API level.
 */
@JvmInline
value class SdkLevel(
    val value: Int,
) {
    fun isAtLeast(level: Int): Boolean = value >= level

    companion object {
        fun current(): SdkLevel = SdkLevel(Build.VERSION.SDK_INT)
    }
}
