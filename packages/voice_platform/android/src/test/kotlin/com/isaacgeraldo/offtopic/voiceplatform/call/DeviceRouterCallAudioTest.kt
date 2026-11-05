package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouter
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import org.junit.Test
import kotlin.test.assertEquals

class DeviceRouterCallAudioTest {
    private val router = ScriptedRouter()
    private val devices = FakeDeviceWatch()
    private val events = RecordingCallEvents()
    private val callAudio = DeviceRouterCallAudio(router, devices::watch, routeExecutor = Runnable::run)

    @Test
    fun `routes without a system call and watches the devices`() {
        assertEquals(CallStart(AudioRouteMessage.SPEAKER, systemCall = false), callAudio.start(events))
        assertEquals(listOf("start"), router.calls)
        assertEquals(true, devices.watching)
    }

    @Test
    fun `re-routes on every device change`() {
        callAudio.start(events)
        router.refreshed = AudioRouteMessage.BLUETOOTH_HEADSET

        devices.change()

        assertEquals(listOf(AudioRouteMessage.BLUETOOTH_HEADSET), events.routes.toList())
    }

    @Test
    fun `stop restores the route and stops watching, once`() {
        callAudio.start(events)

        callAudio.stop()
        callAudio.stop()

        assertEquals(listOf("start", "stop"), router.calls)
        assertEquals(false, devices.watching)
    }

    @Test
    fun `ignores a device change queued before stop`() {
        val queued = mutableListOf<Runnable>()
        val late = DeviceRouterCallAudio(router, devices::watch) { queued += it }
        late.start(events)
        devices.change()
        late.stop()

        queued.forEach { it.run() }

        assertEquals(emptyList(), events.routes.toList())
    }

    private class ScriptedRouter : AudioRouter {
        val calls = mutableListOf<String>()
        var refreshed = AudioRouteMessage.SPEAKER

        override fun start(): AudioRouteMessage {
            calls += "start"
            return AudioRouteMessage.SPEAKER
        }

        override fun refresh(): AudioRouteMessage {
            calls += "refresh"
            return refreshed
        }

        override fun stop() {
            calls += "stop"
        }
    }

    private class FakeDeviceWatch {
        private val listeners = mutableListOf<() -> Unit>()
        val watching: Boolean
            get() = listeners.isNotEmpty()

        fun watch(listener: () -> Unit): AutoCloseable {
            listeners += listener
            return AutoCloseable { listeners -= listener }
        }

        fun change() = listeners.toList().forEach { it() }
    }
}
