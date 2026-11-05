package com.isaacgeraldo.offtopic.voiceplatform.room

import com.isaacgeraldo.offtopic.voiceplatform.PlatformErrorCodes
import com.isaacgeraldo.offtopic.voiceplatform.call.CallAudio
import com.isaacgeraldo.offtopic.voiceplatform.call.CallEvents
import com.isaacgeraldo.offtopic.voiceplatform.call.CallStart
import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.core.FakeVoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.TalkModeMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.VadSensitivityMessage
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class RoomControllerTest {
    private val log = mutableListOf<String>()
    private val core = FakeVoiceCoreBridge(log)
    private val call = RecordingCallAudio(log)
    private var coreCreations = 0
    private val controller =
        RoomController(
            core = {
                coreCreations++
                core
            },
            callAudio = call,
            eventExecutor = Runnable::run,
        )

    @Test
    fun `enters call mode before starting the core`() {
        controller.start(config())

        assertEquals(listOf("call.start", "core.init", "core.start"), log)
        assertEquals("192.168.43.1", core.lastConfig?.hostIp)
        assertEquals(RoomAudioState(AudioRouteMessage.SPEAKER, systemCall = true), controller.currentAudio())
        assertEquals(AudioRouteMessage.SPEAKER, controller.audioRoute)
        assertEquals(config(), controller.activeRoom?.config)
        assertEquals(false, controller.activeRoom?.muted)
    }

    @Test
    fun `leaves call mode when vc_init fails`() {
        core.initResult = CoreResult.INVALID_ARGUMENT

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.INVALID_CONFIG, error.code)
        assertEquals(listOf("call.start", "core.init", "call.stop"), log)
        assertNull(controller.activeRoom)
        assertEquals(RoomAudioState(), controller.currentAudio())
    }

    @Test
    fun `leaves call mode when vc_start fails`() {
        core.startResult = CoreResult.AUDIO_DEVICE

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.AUDIO_DEVICE_ERROR, error.code)
        assertEquals(listOf("call.start", "core.init", "core.start", "call.stop"), log)
        assertNull(controller.activeRoom)
    }

    @Test
    fun `refuses a second room`() {
        controller.start(config())

        val error = assertFailsWith<FlutterError> { controller.start(config()) }

        assertEquals(PlatformErrorCodes.ROOM_ALREADY_ACTIVE, error.code)
    }

    @Test
    fun `stop stops the core then leaves call mode`() {
        controller.start(config())
        log.clear()

        controller.stop()

        assertEquals(listOf("core.stop", "call.stop"), log)
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
    fun `follows the route while the room runs`() {
        controller.start(config())

        call.events?.onRouteChanged(AudioRouteMessage.BLUETOOTH_HEADSET)

        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, controller.audioRoute)
    }

    @Test
    fun `ignores a route reported after the room stopped`() {
        controller.start(config())
        val events = call.events
        controller.stop()

        events?.onRouteChanged(AudioRouteMessage.BLUETOOTH_HEADSET)

        assertEquals(RoomAudioState(), controller.currentAudio())
    }

    @Test
    fun `stops the room when the system ends the call`() {
        controller.start(config())
        log.clear()

        call.events?.onCallEnded()

        assertEquals(listOf("core.stop", "call.stop"), log)
        assertNull(controller.activeRoom)
    }

    @Test
    fun `a hold silences the microphone until the call resumes`() {
        controller.start(config())

        call.events?.onHold(true)
        controller.setMute(false) // the rider cannot unmute a held call
        call.events?.onHold(false)

        assertEquals(listOf(true, true, false), core.mutes)
        assertEquals(false, controller.activeRoom?.muted)
    }

    @Test
    fun `a resume keeps the rider's own mute`() {
        controller.start(config())
        controller.setMute(true)

        call.events?.onHold(true)
        call.events?.onHold(false)

        assertEquals(listOf(true, true, true), core.mutes)
    }

    @Test
    fun `a hold without a room is ignored`() {
        call.events = null
        controller.start(config())
        val events = call.events
        controller.stop()

        events?.onHold(true)

        assertEquals(emptyList(), core.mutes)
    }

    @Test
    fun `tells listeners about every new audio state until they close`() {
        val states = mutableListOf<RoomAudioState>()
        val listening = controller.onAudioChanged { states += it }

        controller.start(config())
        call.events?.onRouteChanged(AudioRouteMessage.BLUETOOTH_HEADSET)
        call.events?.onRouteChanged(AudioRouteMessage.BLUETOOTH_HEADSET) // no news
        controller.stop()
        listening.close()
        controller.start(config())

        assertEquals(
            listOf(
                RoomAudioState(AudioRouteMessage.SPEAKER, systemCall = true),
                RoomAudioState(AudioRouteMessage.BLUETOOTH_HEADSET, systemCall = true),
                RoomAudioState(),
            ),
            states,
        )
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
            talkMode = TalkModeMessage.VOICE,
            vadSensitivity = VadSensitivityMessage.MEDIUM,
        )

    private class RecordingCallAudio(
        private val log: MutableList<String>,
    ) : CallAudio {
        var events: CallEvents? = null

        override fun start(events: CallEvents): CallStart {
            log += "call.start"
            this.events = events
            return CallStart(AudioRouteMessage.SPEAKER, systemCall = true)
        }

        override fun stop() {
            log += "call.stop"
        }
    }
}
