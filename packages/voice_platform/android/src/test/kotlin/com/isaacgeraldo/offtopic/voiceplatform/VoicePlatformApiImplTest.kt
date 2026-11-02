package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.audio.CommunicationDeviceRouter
import com.isaacgeraldo.offtopic.voiceplatform.audio.FakeAudioManagerFacade
import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.core.FakeVoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import com.isaacgeraldo.offtopic.voiceplatform.room.RoomController
import com.isaacgeraldo.offtopic.voiceplatform.system.DeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.KeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class VoicePlatformApiImplTest {
    private val keepScreenOn = RecordingKeepScreenOnController()
    private val core = FakeVoiceCoreBridge()
    private val room = RoomController(core = { core }, router = CommunicationDeviceRouter(FakeAudioManagerFacade()))

    private fun api(dispatcher: TestDispatcher) =
        VoicePlatformApiImpl(
            sdkLevel = SdkLevel(34),
            deviceInfo = FakeDeviceInfoProvider(),
            keepScreenOn = keepScreenOn,
            room = room,
            roomDispatcher = dispatcher,
        )

    @Test
    fun `platform info describes the Android device`() =
        runTest {
            val info = api(StandardTestDispatcher(testScheduler)).getPlatformInfo()

            assertEquals("android", info.osName)
            assertEquals("14", info.osVersion)
            assertEquals(34L, info.apiLevel)
            assertEquals("samsung", info.manufacturer)
            assertEquals("SM-S921B", info.model)
            assertEquals(VoicePlatformApiImpl.ANDROID_CAPABILITIES, info.capabilities)
        }

    @Test
    fun `Android can host rooms and offers every platform helper`() {
        val capabilities = VoicePlatformApiImpl.ANDROID_CAPABILITIES

        assertEquals(true, capabilities.canHostRoom)
        assertEquals(true, capabilities.supportsGatewayDiscovery)
        assertEquals(true, capabilities.supportsHotspotSettings)
        assertEquals(true, capabilities.supportsBatteryExemption)
    }

    @Test
    fun `startRoom starts the room and getActiveRoom reports it`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))

            api.startRoom(sampleConfig())

            assertEquals(sampleConfig(), api.getActiveRoom()?.config)
            assertEquals(false, api.getActiveRoom()?.muted)
        }

    @Test
    fun `startRoom reports core failures as Flutter errors`() =
        runTest {
            core.startResult = CoreResult.NETWORK
            val api = api(StandardTestDispatcher(testScheduler))

            val error = assertFailsWith<FlutterError> { api.startRoom(sampleConfig()) }

            assertEquals(PlatformErrorCodes.NETWORK_ERROR, error.code)
            assertNull(api.getActiveRoom())
        }

    @Test
    fun `stopRoom ends the room`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))
            api.startRoom(sampleConfig())

            api.stopRoom()

            assertNull(api.getActiveRoom())
        }

    @Test
    fun `setMute reaches the core`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))
            api.startRoom(sampleConfig())

            api.setMute(true)

            assertEquals(listOf(true), core.mutes)
            assertEquals(true, api.getActiveRoom()?.muted)
        }

    @Test
    fun `there is no active room at first`() =
        runTest {
            assertNull(api(StandardTestDispatcher(testScheduler)).getActiveRoom())
        }

    @Test
    fun `requestBatteryExemption is not implemented yet`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))
            val error = assertFailsWith<FlutterError> { api.requestBatteryExemption() }

            assertEquals(PlatformErrorCodes.NOT_IMPLEMENTED, error.code)
        }

    @Test
    fun `openHotspotSettings is not implemented yet`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))
            val error = assertFailsWith<FlutterError> { api.openHotspotSettings() }

            assertEquals(PlatformErrorCodes.NOT_IMPLEMENTED, error.code)
            assertEquals("openHotspotSettings is not implemented yet on Android.", error.message)
        }

    @Test
    fun `setKeepScreenOn delegates to the controller`() =
        runTest {
            val api = api(StandardTestDispatcher(testScheduler))
            api.setKeepScreenOn(true)
            api.setKeepScreenOn(false)

            assertEquals(listOf(true, false), keepScreenOn.calls)
        }

    private fun sampleConfig() =
        RoomConfigMessage(
            role = RoomRoleMessage.CLIENT,
            hostIp = "192.168.43.1",
            displayName = "Ana",
            controlPort = 47800,
            audioPort = 47801,
            bitrateBps = 24000,
            echoMode = false,
        )

    private class FakeDeviceInfoProvider : DeviceInfoProvider {
        override val manufacturer = "samsung"
        override val model = "SM-S921B"
        override val osVersion = "14"
    }

    private class RecordingKeepScreenOnController : KeepScreenOnController {
        val calls = mutableListOf<Boolean>()

        override fun setKeepScreenOn(enabled: Boolean) {
            calls += enabled
        }
    }
}
