package com.isaacgeraldo.offtopic.voiceplatform.system

import android.os.Build

/** Static facts about the device, used for diagnostics and per-manufacturer guidance. */
interface DeviceInfoProvider {
    val manufacturer: String
    val model: String
    val osVersion: String
}

/** Reads the device facts from [Build]. */
class AndroidDeviceInfoProvider : DeviceInfoProvider {
    override val manufacturer: String get() = Build.MANUFACTURER
    override val model: String get() = Build.MODEL
    override val osVersion: String get() = Build.VERSION.RELEASE
}
