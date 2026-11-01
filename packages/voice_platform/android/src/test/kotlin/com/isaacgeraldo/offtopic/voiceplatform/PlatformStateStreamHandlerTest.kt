package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PigeonEventSink
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.WifiStateMessage
import io.mockk.confirmVerified
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test
import kotlin.test.assertEquals

class PlatformStateStreamHandlerTest {
    @Test
    fun `new listeners receive the idle state once`() {
        val sink = mockk<PigeonEventSink<PlatformStateMessage>>(relaxed = true)

        PlatformStateStreamHandler().onListen(null, sink)

        verify(exactly = 1) { sink.success(PlatformStateStreamHandler.IDLE_STATE) }
        confirmVerified(sink)
    }

    @Test
    fun `idle state has no service, no route and unknown Wi-Fi`() {
        val state = PlatformStateStreamHandler.IDLE_STATE

        assertEquals(false, state.serviceRunning)
        assertEquals(AudioRouteMessage.UNKNOWN, state.audioRoute)
        assertEquals(WifiStateMessage.UNKNOWN, state.wifiState)
    }
}
