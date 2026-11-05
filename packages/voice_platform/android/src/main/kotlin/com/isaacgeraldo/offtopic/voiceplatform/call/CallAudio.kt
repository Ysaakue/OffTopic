package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage

/**
 * Puts the phone in call mode for the room and keeps its audio on the best
 * device: the Bluetooth intercom, then a wired or USB headset, then the
 * loudspeaker.
 */
internal interface CallAudio {
    /**
     * Enters call mode and applies the best route, waiting (bounded) until it
     * is in place: AAudio streams opened before the route lands get moved, and
     * a stream moved while it starts is disconnected. Blocks: call it off the
     * main thread.
     */
    fun start(events: CallEvents): CallStart

    /** Leaves call mode. Idempotent. */
    fun stop()
}

/** How the room entered call mode. */
internal data class CallStart(
    val route: AudioRouteMessage,
    /** Registered as a call with the system (Telecom), not only routed. */
    val systemCall: Boolean,
)

/** What happens to the call while the room runs. Implementations must not block. */
internal interface CallEvents {
    fun onRouteChanged(route: AudioRouteMessage)

    /** The system ended the call (a headset's hang-up button, a car, ...). */
    fun onCallEnded()

    /** Another call put this one on hold (true), or gave it back (false). */
    fun onHold(held: Boolean)
}
