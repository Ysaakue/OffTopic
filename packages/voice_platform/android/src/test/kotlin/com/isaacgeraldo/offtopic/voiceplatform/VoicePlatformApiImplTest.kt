package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import com.isaacgeraldo.offtopic.voiceplatform.system.DeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.KeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class VoicePlatformApiImplTest {
    private val keepScreenOn = RecordingKeepScreenOnController()
    private val api =
        VoicePlatformApiImpl(
            sdkLevel = SdkLevel(34),
            deviceInfo = FakeDeviceInfoProvider(),
            keepScreenOn = keepScreenOn,
        )

    @Test
    fun `platform info describes the Android device`() {
        val info = api.getPlatformInfo()

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
    fun `startRoom is not implemented yet`() =
        runTest {
            val error = assertFailsWith<FlutterError> { api.startRoom(sampleConfig()) }

            assertEquals(PlatformErrorCodes.NOT_IMPLEMENTED, error.code)
            assertEquals("startRoom is not implemented yet on Android.", error.message)
        }

    @Test
    fun `stopRoom is not implemented yet`() =
        runTest {
            assertNotImplemented { api.stopRoom() }
        }

    @Test
    fun `requestBatteryExemption is not implemented yet`() =
        runTest {
            assertNotImplemented { api.requestBatteryExemption() }
        }

    @Test
    fun `setMute is not implemented yet`() =
        runTest {
            assertNotImplemented { api.setMute(true) }
        }

    @Test
    fun `openHotspotSettings is not implemented yet`() =
        runTest {
            assertNotImplemented { api.openHotspotSettings() }
        }

    @Test
    fun `setKeepScreenOn delegates to the controller`() {
        api.setKeepScreenOn(true)
        api.setKeepScreenOn(false)

        assertEquals(listOf(true, false), keepScreenOn.calls)
    }

    @Test
    fun `there is no active room before the service exists`() {
        assertNull(api.getActiveRoom())
    }

    private suspend fun assertNotImplemented(block: suspend () -> Unit) {
        val error =
            try {
                block()
                null
            } catch (expected: FlutterError) {
                expected
            }
        assertEquals(PlatformErrorCodes.NOT_IMPLEMENTED, error?.code)
    }

    private fun sampleConfig() =
        RoomConfigMessage(
            role = RoomRoleMessage.CLIENT,
            hostIp = "192.168.43.1",
            displayName = "Ana",
            controlPort = 47800,
            audioPort = 47801,
            bitrateBps = 24000,
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
