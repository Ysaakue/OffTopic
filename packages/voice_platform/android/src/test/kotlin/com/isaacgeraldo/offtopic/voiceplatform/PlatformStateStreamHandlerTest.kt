package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PigeonEventSink
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.WifiStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.room.AudioRouteSource
import com.isaacgeraldo.offtopic.voiceplatform.room.RoomAudioState
import io.mockk.confirmVerified
import io.mockk.mockk
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Test
import java.util.concurrent.Executor
import kotlin.test.assertEquals

class PlatformStateStreamHandlerTest {
    private val routes = FakeAudioSource()
    private val posted = mutableListOf<Runnable>()
    private val mainThread = Executor { posted += it }
    private val handler = PlatformStateStreamHandler(routes, mainThread)
    private val sink = mockk<PigeonEventSink<PlatformStateMessage>>(relaxed = true)

    @Test
    fun `a new listener receives the current state`() {
        routes.audio = RoomAudioState(AudioRouteMessage.SPEAKER, systemCall = true)

        handler.onListen(null, sink)

        verify(exactly = 1) {
            sink.success(
                PlatformStateStreamHandler.stateFor(RoomAudioState(AudioRouteMessage.SPEAKER, systemCall = true)),
            )
        }
        confirmVerified(sink)
    }

    @Test
    fun `route changes reach the listener on the main thread`() {
        handler.onListen(null, sink)

        routes.change(AudioRouteMessage.BLUETOOTH_HEADSET)
        verify(exactly = 1) { sink.success(any()) } // not yet: queued for the main thread
        posted.forEach { it.run() }

        verifyOrder {
            sink.success(PlatformStateStreamHandler.IDLE_STATE)
            sink.success(PlatformStateStreamHandler.stateFor(RoomAudioState(AudioRouteMessage.BLUETOOTH_HEADSET)))
        }
    }

    @Test
    fun `cancelling stops the updates`() {
        handler.onListen(null, sink)

        handler.onCancel(null)
        routes.change(AudioRouteMessage.SPEAKER)

        assertEquals(0, routes.listeners.size)
        assertEquals(emptyList(), posted)
    }

    @Test
    fun `listening again replaces the previous subscription`() {
        handler.onListen(null, sink)

        handler.onListen(null, sink)

        assertEquals(1, routes.listeners.size)
    }

    @Test
    fun `the idle state has no service, no route and unknown Wi-Fi`() {
        val state = PlatformStateStreamHandler.IDLE_STATE

        assertEquals(false, state.serviceRunning)
        assertEquals(AudioRouteMessage.UNKNOWN, state.audioRoute)
        assertEquals(WifiStateMessage.UNKNOWN, state.wifiState)
        assertEquals(false, state.systemCall)
    }

    private class FakeAudioSource : AudioRouteSource {
        var audio = RoomAudioState()
        val listeners = mutableListOf<(RoomAudioState) -> Unit>()

        fun change(newRoute: AudioRouteMessage) {
            audio = RoomAudioState(newRoute)
            listeners.toList().forEach { it(audio) }
        }

        override fun currentAudio(): RoomAudioState = audio

        override fun onAudioChanged(listener: (RoomAudioState) -> Unit): AutoCloseable {
            listeners += listener
            return AutoCloseable { listeners -= listener }
        }
    }
}
