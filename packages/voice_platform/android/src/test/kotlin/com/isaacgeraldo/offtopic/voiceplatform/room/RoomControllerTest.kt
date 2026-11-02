package com.isaacgeraldo.offtopic.voiceplatform.room

import com.isaacgeraldo.offtopic.voiceplatform.PlatformErrorCodes
import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouter
import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.core.FakeVoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class RoomControllerTest {
    private val log = mutableListOf<String>()
    private val core = FakeVoiceCoreBridge(log)
    private val router = RecordingRouter(log)
    private var coreCreations = 0
    private val controller =
        RoomController(
            core = {
                coreCreations++
                core
            },
            router = router,
        )

    @Test
    fun `routes the audio before starting the core`() {
        controller.start(config())

        assertEquals(listOf("route.start", "core.init", "core.start"), log)
        assertEquals("192.168.43.1", core.lastConfig?.hostIp)
        assertEquals(AudioRouteMessage.SPEAKER, controller.audioRoute)
        assertEquals(config(), controller.activeRoom?.config)
        assertEquals(false, controller.activeRoom?.muted)
    }

    @Test
    fun `undoes the route when vc_init fails`() {
        core.initResult = CoreResult.INVALID_ARGUMENT

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.INVALID_CONFIG, error.code)
        assertEquals(listOf("route.start", "core.init", "route.stop"), log)
        assertNull(controller.activeRoom)
        assertEquals(AudioRouteMessage.UNKNOWN, controller.audioRoute)
    }

    @Test
    fun `undoes the route when vc_start fails`() {
        core.startResult = CoreResult.AUDIO_DEVICE

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.AUDIO_DEVICE_ERROR, error.code)
        assertEquals(listOf("route.start", "core.init", "core.start", "route.stop"), log)
        assertNull(controller.activeRoom)
    }

    @Test
    fun `refuses a second room`() {
        controller.start(config())

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.ROOM_ALREADY_ACTIVE, error.code)
    }

    @Test
    fun `stop stops the core then restores the route`() {
        controller.start(config())
        log.clear()

        controller.stop()

        assertEquals(listOf("core.stop", "route.stop"), log)
        assertNull(controller.activeRoom)
    }

    @Test
    fun `stop is idempotent and never loads the core needlessly`() {
        controller.stop()
        controller.stop()

        assertEquals(emptyList(), log)
        assertEquals(0, coreCreations)
    }

    @Test
    fun `mute reaches the core and the active room`() {
        controller.start(config())

        controller.setMute(true)

        assertEquals(listOf(true), core.mutes)
        assertEquals(true, controller.activeRoom?.muted)
    }

    @Test
    fun `mute without a room fails`() {
        val error = assertFailsWith<FlutterError> { controller.setMute(true) }

        assertEquals(PlatformErrorCodes.NO_ACTIVE_ROOM, error.code)
    }

    @Test
    fun `can start again after stopping`() {
        controller.start(config())
        controller.stop()

        controller.start(config())

        assertEquals(config(), controller.activeRoom?.config)
    }

    private fun config() =
        RoomConfigMessage(
            role = RoomRoleMessage.CLIENT,
            hostIp = "192.168.43.1",
            displayName = "Ana",
            controlPort = 47800,
            audioPort = 47801,
            bitrateBps = 24000,
            echoMode = false,
        )

    private class RecordingRouter(
        private val log: MutableList<String>,
    ) : AudioRouter {
        override fun start(): AudioRouteMessage {
            log += "route.start"
            return AudioRouteMessage.SPEAKER
        }

        override fun stop() {
            log += "route.stop"
        }
    }
}
