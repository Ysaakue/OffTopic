package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.PigeonEventSink
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateStreamHandler
import com.isaacgeraldo.offtopic.voiceplatform.generated.WifiStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.room.AudioRouteSource
import com.isaacgeraldo.offtopic.voiceplatform.room.RoomAudioState
import java.util.concurrent.Executor

/**
 * Streams the platform state to Dart: the current state on listen, then one
 * update per change of the room's audio (route, system call). The service
 * and Wi-Fi parts arrive in phase 4 (always "not running" and "unknown" until
 * then).
 *
 * @param audio the room's audio and its changes (RoomController).
 * @param mainExecutor event channels must be fed on the main thread.
 */
internal class PlatformStateStreamHandler(
    private val audio: AudioRouteSource,
    private val mainExecutor: Executor,
) : WatchPlatformStateStreamHandler() {
    private var subscription: AutoCloseable? = null

    override fun onListen(
        p0: Any?,
        sink: PigeonEventSink<PlatformStateMessage>,
    ) {
        subscription?.close()
        sink.success(stateFor(audio.currentAudio()))
        subscription = audio.onAudioChanged { state -> mainExecutor.execute { sink.success(stateFor(state)) } }
    }

    override fun onCancel(p0: Any?) {
        subscription?.close()
        subscription = null
    }

    companion object {
        fun stateFor(audio: RoomAudioState) =
            PlatformStateMessage(
                serviceRunning = false,
                audioRoute = audio.route,
                wifiState = WifiStateMessage.UNKNOWN,
                systemCall = audio.systemCall,
            )

        val IDLE_STATE = stateFor(RoomAudioState())
    }
}
