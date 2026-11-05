package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull

/**
 * [CallAudio] through the system's call registry: the room is a call, as in
 * WhatsApp or a phone call. Bluetooth headsets then see a real call (and turn
 * on their own noise suppression), and Telecom owns the audio mode and route;
 * this class only asks for the preferred endpoint.
 *
 * @param scope where the call lives (beyond start()).
 * @param startTimeoutMs how long start() waits for the call and its route.
 */
internal class TelecomCallAudio(
    private val platform: CallPlatform,
    private val scope: CoroutineScope,
    private val displayName: String,
    private val startTimeoutMs: Long = START_TIMEOUT_MS,
    private val routeSettleMs: Long = ROUTE_SETTLE_MS,
    private val stopTimeoutMs: Long = STOP_TIMEOUT_MS,
) : CallAudio {
    private var call: Job? = null
    private var endRequest: CompletableDeferred<Unit>? = null
    private var ended: CompletableDeferred<Unit>? = null

    @Volatile
    private var endingLocally = false

    @Synchronized
    override fun start(events: CallEvents): CallStart {
        check(call == null) { "A call is already running." }
        val ready = CompletableDeferred<AudioRouteMessage>()
        val end = CompletableDeferred<Unit>()
        val done = CompletableDeferred<Unit>()
        endingLocally = false
        endRequest = end
        ended = done
        call =
            scope.launch {
                try {
                    platform.addCall(displayName, callbacksFor(events)) { session ->
                        session.scope.launch { runCall(session, events, ready, end, done) }
                    }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (refused: Exception) {
                    ready.completeExceptionally(refused)
                }
            }
        return try {
            CallStart(route = runBlocking { withTimeout(startTimeoutMs) { ready.await() } }, systemCall = true)
        } catch (failure: Exception) {
            stop()
            throw failure
        }
    }

    @Synchronized
    override fun stop() {
        val end = endRequest ?: return
        endingLocally = true
        end.complete(Unit)
        runBlocking { withTimeoutOrNull(stopTimeoutMs) { ended?.await() } }
        call?.cancel()
        call = null
        endRequest = null
        ended = null
    }

    private suspend fun CoroutineScope.runCall(
        session: CallSession,
        events: CallEvents,
        ready: CompletableDeferred<AudioRouteMessage>,
        end: CompletableDeferred<Unit>,
        done: CompletableDeferred<Unit>,
    ) {
        try {
            if (!session.setActive()) {
                ready.completeExceptionally(IllegalStateException("Telecom refused to make the call active."))
                session.disconnect()
                return
            }
            val best = bestOf(session.availableEndpoints.first())
            if (best != null) {
                session.requestEndpoint(best)
            }
            // The first route reported once the requested one is in place (or after a bounded wait).
            val settled =
                withTimeoutOrNull(routeSettleMs) {
                    session.currentEndpoint.first { best == null || it.type == best.type }
                }
                    ?: session.currentEndpoint.first()
            launch { session.currentEndpoint.collect { events.onRouteChanged(routeOf(it)) } }
            launch { followPreferredEndpoint(session) }
            ready.complete(routeOf(settled))
            end.await()
            session.disconnect()
        } finally {
            done.complete(Unit)
        }
    }

    // Devices come and go during a ride (the intercom reconnects): keep asking
    // for the preferred one. Telecom ignores a request for the current endpoint.
    private suspend fun followPreferredEndpoint(session: CallSession) {
        var requested: EndpointType? = null
        session.availableEndpoints.collect { endpoints ->
            val best = bestOf(endpoints)
            if (best != null && best.type != requested) {
                requested = best.type
                session.requestEndpoint(best)
            }
        }
    }

    private fun callbacksFor(events: CallEvents) =
        object : CallSessionCallbacks {
            override suspend fun onDisconnect() {
                if (!endingLocally) {
                    events.onCallEnded()
                }
            }

            override suspend fun onSetActive() = events.onHold(false)

            override suspend fun onSetInactive() = events.onHold(true)
        }

    companion object {
        const val START_TIMEOUT_MS = 5_000L
        const val ROUTE_SETTLE_MS = 1_500L
        const val STOP_TIMEOUT_MS = 2_000L

        private val PREFERENCE = listOf(EndpointType.BLUETOOTH, EndpointType.WIRED_HEADSET, EndpointType.SPEAKER)

        fun bestOf(endpoints: List<CallEndpoint>): CallEndpoint? =
            PREFERENCE.firstNotNullOfOrNull { type -> endpoints.firstOrNull { it.type == type } }

        fun routeOf(endpoint: CallEndpoint): AudioRouteMessage =
            when (endpoint.type) {
                EndpointType.BLUETOOTH -> AudioRouteMessage.BLUETOOTH_HEADSET
                EndpointType.WIRED_HEADSET -> AudioRouteMessage.WIRED_HEADSET
                EndpointType.SPEAKER -> AudioRouteMessage.SPEAKER
                EndpointType.EARPIECE -> AudioRouteMessage.EARPIECE
                EndpointType.OTHER -> AudioRouteMessage.UNKNOWN
            }
    }
}
