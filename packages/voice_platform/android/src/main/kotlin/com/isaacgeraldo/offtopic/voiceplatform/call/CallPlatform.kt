package com.isaacgeraldo.offtopic.voiceplatform.call

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow

/** Where a call can be heard, as the routing logic sees a Telecom endpoint. */
internal data class CallEndpoint(
    val type: EndpointType,
    val handle: Any? = null,
)

internal enum class EndpointType {
    BLUETOOTH,
    WIRED_HEADSET,
    SPEAKER,
    EARPIECE,
    OTHER,
}

/** One call registered with the system, seen from inside it. */
internal interface CallSession {
    /** Lives as long as the call; coroutines launched here end with it. */
    val scope: CoroutineScope

    val currentEndpoint: Flow<CallEndpoint>

    val availableEndpoints: Flow<List<CallEndpoint>>

    /** Whether the system accepted the call as active. */
    suspend fun setActive(): Boolean

    /** Whether the system accepted the request (the switch itself is reported by [currentEndpoint]). */
    suspend fun requestEndpoint(endpoint: CallEndpoint): Boolean

    /** Ends the call from this side. */
    suspend fun disconnect()
}

/**
 * What the system asks of a running call: a headset's hang-up button, a car,
 * or another call taking over. Each must return within a few seconds.
 */
internal interface CallSessionCallbacks {
    suspend fun onDisconnect()

    suspend fun onSetActive()

    suspend fun onSetInactive()
}

/** The system's registry of calls (Android Telecom). */
internal interface CallPlatform {
    /**
     * Registers an outgoing audio call and runs [onCall] inside it. Throws
     * when the system refuses the call (no Telecom on the device, another
     * call that cannot be held...).
     */
    suspend fun addCall(
        displayName: String,
        callbacks: CallSessionCallbacks,
        onCall: (CallSession) -> Unit,
    )
}
