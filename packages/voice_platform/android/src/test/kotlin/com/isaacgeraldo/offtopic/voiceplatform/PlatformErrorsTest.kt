package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import org.junit.Test
import kotlin.test.assertEquals

class PlatformErrorsTest {
    @Test
    fun `core results map to the codes Dart understands`() {
        val expected =
            mapOf(
                CoreResult.INVALID_ARGUMENT to PlatformErrorCodes.INVALID_CONFIG,
                CoreResult.INVALID_STATE to PlatformErrorCodes.ROOM_ALREADY_ACTIVE,
                CoreResult.AUDIO_DEVICE to PlatformErrorCodes.AUDIO_DEVICE_ERROR,
                CoreResult.NETWORK to PlatformErrorCodes.NETWORK_ERROR,
                CoreResult.CODEC to PlatformErrorCodes.CORE_ERROR,
                CoreResult.INTERNAL to PlatformErrorCodes.CORE_ERROR,
            )

        expected.forEach { (result, code) ->
            val error = PlatformErrors.core("vc_start", result)
            assertEquals(code, error.code)
            assertEquals(result.toLong(), error.details)
            assertEquals("vc_start failed with voice core error $result.", error.message)
        }
    }

    @Test
    fun `room state errors have their own codes`() {
        assertEquals(PlatformErrorCodes.ROOM_ALREADY_ACTIVE, PlatformErrors.roomAlreadyActive().code)
        assertEquals(PlatformErrorCodes.NO_ACTIVE_ROOM, PlatformErrors.noActiveRoom().code)
        assertEquals(PlatformErrorCodes.NOT_IMPLEMENTED, PlatformErrors.notImplemented("x").code)
    }
}
