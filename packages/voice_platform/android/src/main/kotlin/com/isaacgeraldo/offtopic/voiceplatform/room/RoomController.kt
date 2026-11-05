package com.isaacgeraldo.offtopic.voiceplatform.room

import com.isaacgeraldo.offtopic.voiceplatform.PlatformErrors
import com.isaacgeraldo.offtopic.voiceplatform.call.CallAudio
import com.isaacgeraldo.offtopic.voiceplatform.call.CallEvents
import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.core.VoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.core.toCoreConfig
import com.isaacgeraldo.offtopic.voiceplatform.generated.ActiveRoomMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executor

/**
 * Owns the running room: call mode and audio route first, then the core; on
 * failure every step already taken is undone. While the room runs it follows
 * the call: route changes, a hold by another call (the microphone goes quiet)
 * and the system ending the call (the room stops; the core reports it to
 * Dart). Thread-safe (Pigeon calls arrive on the main thread, the slow start
 * runs on a background dispatcher, call events on [eventExecutor]). From
 * phase 4 it lives inside the foreground service.
 *
 * @param core created lazily: loading the native library is the first use.
 * @param eventExecutor where call events are handled: never on the system's
 *   callback thread, which must not wait for this controller's lock.
 */
internal class RoomController(
    private val core: () -> VoiceCoreBridge,
    private val callAudio: CallAudio,
    private val eventExecutor: Executor,
) : AudioRouteSource {
    private var active: ActiveRoomMessage? = null
    private var audio = RoomAudioState()
    private var held = false
    private var inCall = false
    private val listeners = CopyOnWriteArraySet<(RoomAudioState) -> Unit>()

    private val events =
        object : CallEvents {
            override fun onRouteChanged(route: AudioRouteMessage) = eventExecutor.execute { routeChanged(route) }

            override fun onCallEnded() = eventExecutor.execute(::callEnded)

            override fun onHold(held: Boolean) = eventExecutor.execute { hold(held) }
        }

    val activeRoom: ActiveRoomMessage?
        @Synchronized get() = active

    val audioRoute: AudioRouteMessage
        @Synchronized get() = audio.route

    @Synchronized
    override fun currentAudio(): RoomAudioState = audio

    override fun onAudioChanged(listener: (RoomAudioState) -> Unit): AutoCloseable {
        listeners += listener
        return AutoCloseable { listeners -= listener }
    }

    @Synchronized
    fun start(config: RoomConfigMessage) {
        if (active != null) {
            throw PlatformErrors.roomAlreadyActive()
        }
        val bridge = core()
        val call = callAudio.start(events)
        inCall = true
        held = false
        updateAudio(RoomAudioState(call.route, call.systemCall))
        val initResult = bridge.init(config.toCoreConfig())
        if (initResult != CoreResult.OK) {
            leaveCall()
            throw PlatformErrors.core("vc_init", initResult)
        }
        val startResult = bridge.start()
        if (startResult != CoreResult.OK) {
            leaveCall()
            throw PlatformErrors.core("vc_start", startResult)
        }
        active = ActiveRoomMessage(config = config, muted = false)
    }

    @Synchronized
    fun stop() {
        if (active == null) {
            return
        }
        core().stop()
        leaveCall()
        active = null
    }

    @Synchronized
    fun setMute(muted: Boolean) {
        val room = active ?: throw PlatformErrors.noActiveRoom()
        core().setMute(muted || held)
        active = room.copy(muted = muted)
    }

    @Synchronized
    private fun routeChanged(route: AudioRouteMessage) {
        if (inCall) {
            updateAudio(audio.copy(route = route))
        }
    }

    // The core's "stopped" event tells Dart that the room is over.
    @Synchronized
    private fun callEnded() = stop()

    @Synchronized
    private fun hold(held: Boolean) {
        val room = active ?: return
        this.held = held
        core().setMute(room.muted || held)
    }

    private fun leaveCall() {
        inCall = false
        callAudio.stop()
        updateAudio(RoomAudioState())
    }

    private fun updateAudio(newAudio: RoomAudioState) {
        if (newAudio != audio) {
            audio = newAudio
            listeners.forEach { it(newAudio) }
        }
    }
}
