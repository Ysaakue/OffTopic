package com.isaacgeraldo.offtopic.voiceplatform.room

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage

/** The room's audio as the platform state stream reports it. */
internal data class RoomAudioState(
    val route: AudioRouteMessage = AudioRouteMessage.UNKNOWN,
    /** The room is registered as a call with the system (not only routed). */
    val systemCall: Boolean = false,
)

/** The current [RoomAudioState], and every change of it. */
internal interface AudioRouteSource {
    fun currentAudio(): RoomAudioState

    /** Calls [listener] with every new state (on the thread that changed it), until closed. */
    fun onAudioChanged(listener: (RoomAudioState) -> Unit): AutoCloseable
}
