package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.ActiveRoomMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformCapabilitiesMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformInfoMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.VoicePlatformHostApi
import com.isaacgeraldo.offtopic.voiceplatform.room.RoomController
import com.isaacgeraldo.offtopic.voiceplatform.system.DeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.KeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext

/**
 * Android implementation of the Pigeon host API.
 *
 * Methods owned by later phases fail with [PlatformErrorCodes.NOT_IMPLEMENTED]
 * so that Dart can tell "not built yet" apart from a real failure.
 *
 * @param roomDispatcher where the room starts and stops (opening the audio
 *   device and the socket must not block the main thread).
 */
internal class VoicePlatformApiImpl(
    private val sdkLevel: SdkLevel,
    private val deviceInfo: DeviceInfoProvider,
    private val keepScreenOn: KeepScreenOnController,
    private val room: RoomController,
    private val roomDispatcher: CoroutineDispatcher,
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

    override suspend fun startRoom(config: RoomConfigMessage) = withContext(roomDispatcher) { room.start(config) }

    override suspend fun stopRoom() = withContext(roomDispatcher) { room.stop() }

    override fun setMute(muted: Boolean) = room.setMute(muted)

    override fun openHotspotSettings(): Unit = throw PlatformErrors.notImplemented("openHotspotSettings")

    override suspend fun requestBatteryExemption(): Boolean =
        throw PlatformErrors.notImplemented("requestBatteryExemption")

    override fun setKeepScreenOn(enabled: Boolean) = keepScreenOn.setKeepScreenOn(enabled)

    override fun getActiveRoom(): ActiveRoomMessage? = room.activeRoom

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
