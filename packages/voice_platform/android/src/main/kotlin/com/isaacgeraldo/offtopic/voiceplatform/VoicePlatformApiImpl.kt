package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.ActiveRoomMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformCapabilitiesMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformInfoMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.VoicePlatformHostApi
import com.isaacgeraldo.offtopic.voiceplatform.system.DeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.KeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel

/**
 * Android implementation of the Pigeon host API.
 *
 * Methods owned by later phases fail with [PlatformErrorCodes.NOT_IMPLEMENTED]
 * so that Dart can tell "not built yet" apart from a real failure.
 */
internal class VoicePlatformApiImpl(
    private val sdkLevel: SdkLevel,
    private val deviceInfo: DeviceInfoProvider,
    private val keepScreenOn: KeepScreenOnController,
) : VoicePlatformHostApi {
    override fun getPlatformInfo(): PlatformInfoMessage =
        PlatformInfoMessage(
            osName = OS_NAME,
            osVersion = deviceInfo.osVersion,
            apiLevel = sdkLevel.value.toLong(),
            manufacturer = deviceInfo.manufacturer,
            model = deviceInfo.model,
            capabilities = ANDROID_CAPABILITIES,
        )

    override suspend fun startRoom(config: RoomConfigMessage): Unit = throw PlatformErrors.notImplemented("startRoom")

    override suspend fun stopRoom(): Unit = throw PlatformErrors.notImplemented("stopRoom")

    override fun setMute(muted: Boolean): Unit = throw PlatformErrors.notImplemented("setMute")

    override fun openHotspotSettings(): Unit = throw PlatformErrors.notImplemented("openHotspotSettings")

    override suspend fun requestBatteryExemption(): Boolean =
        throw PlatformErrors.notImplemented("requestBatteryExemption")

    override fun setKeepScreenOn(enabled: Boolean) = keepScreenOn.setKeepScreenOn(enabled)

    /** No room can be running before the foreground service exists (phase 4). */
    override fun getActiveRoom(): ActiveRoomMessage? = null

    companion object {
        const val OS_NAME = "android"

        val ANDROID_CAPABILITIES =
            PlatformCapabilitiesMessage(
                canHostRoom = true,
                supportsGatewayDiscovery = true,
                supportsHotspotSettings = true,
                supportsBatteryExemption = true,
            )
    }
}
