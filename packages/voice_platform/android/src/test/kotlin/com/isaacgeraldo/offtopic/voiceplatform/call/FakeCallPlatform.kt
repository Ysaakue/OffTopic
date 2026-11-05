package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Plays Telecom for TelecomCallAudio: endpoints as state flows, a call that
 * lives until it is disconnected, and the callbacks the system would invoke.
 */
internal class FakeCallPlatform : CallPlatform {
    /** When set, addCall throws it (the system refuses the call). */
    var refusal: Exception? = null

    /** When false, addCall never hands out the call (the system hangs). */
    var answers = true

    var activates = true

    /** When false, endpoint requests are accepted but the route never changes. */
    var appliesRequests = true

    val available = MutableStateFlow(listOf(EARPIECE, SPEAKER))
    val current = MutableStateFlow(EARPIECE)
    val requests = CopyOnWriteArrayList<EndpointType>()
    val names = CopyOnWriteArrayList<String>()

    @Volatile
    var disconnects = 0

    @Volatile
    private var callbacks: CallSessionCallbacks? = null

    @Volatile
    private var callScope: CoroutineScope? = null

    override suspend fun addCall(
        displayName: String,
        callbacks: CallSessionCallbacks,
        onCall: (CallSession) -> Unit,
    ) {
        names += displayName
        refusal?.let { throw it }
        if (!answers) {
            awaitCancellation()
        }
        this.callbacks = callbacks
        // Like Telecom: the call lives until it is disconnected.
        coroutineScope {
            callScope = this
            onCall(Session(this))
        }
    }

    /** The system ends the call (e.g. the headset's hang-up button). */
    suspend fun endFromSystem() {
        callbacks?.onDisconnect()
        callScope?.cancel()
    }

    suspend fun putOnHold() = callbacks?.onSetInactive()

    suspend fun resume() = callbacks?.onSetActive()

    private inner class Session(
        override val scope: CoroutineScope,
    ) : CallSession {
        override val currentEndpoint = current
        override val availableEndpoints = available

        override suspend fun setActive() = activates

        override suspend fun requestEndpoint(endpoint: CallEndpoint): Boolean {
            requests += endpoint.type
            if (appliesRequests) {
                current.value = endpoint
            }
            return true
        }

        override suspend fun disconnect() {
            disconnects++
            // Telecom also echoes a local disconnect through the callback.
            callbacks?.onDisconnect()
            scope.cancel()
        }
    }

    companion object {
        val EARPIECE = CallEndpoint(EndpointType.EARPIECE)
        val SPEAKER = CallEndpoint(EndpointType.SPEAKER)
        val HEADSET = CallEndpoint(EndpointType.WIRED_HEADSET)
        val INTERCOM = CallEndpoint(EndpointType.BLUETOOTH)
    }
}

/** Records what the call reports, thread-safely. */
internal class RecordingCallEvents : CallEvents {
    val routes = CopyOnWriteArrayList<AudioRouteMessage>()
    val holds = CopyOnWriteArrayList<Boolean>()

    @Volatile
    var ends = 0

    val firstEnd = CompletableDeferred<Unit>()

    override fun onRouteChanged(route: AudioRouteMessage) {
        routes += route
    }

    override fun onCallEnded() {
        ends++
        firstEnd.complete(Unit)
    }

    override fun onHold(held: Boolean) {
        holds += held
    }
}
