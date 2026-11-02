package com.isaacgeraldo.offtopic.voiceplatform.room

import com.isaacgeraldo.offtopic.voiceplatform.PlatformErrors
import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouter
import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.core.VoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.core.toCoreConfig
import com.isaacgeraldo.offtopic.voiceplatform.generated.ActiveRoomMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage

/**
 * Owns the running room: audio route first, then the core; on failure every
 * step already taken is undone. Thread-safe (Pigeon calls arrive on the main
 * thread, the slow start runs on a background dispatcher). From phase 4 it
 * lives inside the foreground service.
 *
 * @param core created lazily: loading the native library is the first use.
 */
internal class RoomController(
    private val core: () -> VoiceCoreBridge,
    private val router: AudioRouter,
) {
    private var active: ActiveRoomMessage? = null
    private var route: AudioRouteMessage = AudioRouteMessage.UNKNOWN

    val activeRoom: ActiveRoomMessage?
        @Synchronized get() = active

    val audioRoute: AudioRouteMessage
        @Synchronized get() = route

    @Synchronized
    fun start(config: RoomConfigMessage) {
        if (active != null) {
            throw PlatformErrors.roomAlreadyActive()
        }
        val bridge = core()
        route = router.start()
        val initResult = bridge.init(config.toCoreConfig())
        if (initResult != CoreResult.OK) {
            rollBack()
            throw PlatformErrors.core("vc_init", initResult)
        }
        val startResult = bridge.start()
        if (startResult != CoreResult.OK) {
            rollBack()
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
        rollBack()
        active = null
    }

    @Synchronized
    fun setMute(muted: Boolean) {
        val room = active ?: throw PlatformErrors.noActiveRoom()
        core().setMute(muted)
        active = room.copy(muted = muted)
    }

    private fun rollBack() {
        router.stop()
        route = AudioRouteMessage.UNKNOWN
    }
}
