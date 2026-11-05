package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.call.FakeCallPlatform.Companion.EARPIECE
import com.isaacgeraldo.offtopic.voiceplatform.call.FakeCallPlatform.Companion.HEADSET
import com.isaacgeraldo.offtopic.voiceplatform.call.FakeCallPlatform.Companion.INTERCOM
import com.isaacgeraldo.offtopic.voiceplatform.call.FakeCallPlatform.Companion.SPEAKER
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

// The call runs on real dispatcher threads (start() blocks until it is
// ready), so state reported later is awaited with a bound; the timeouts only
// bound a failure.
class TelecomCallAudioTest {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val platform = FakeCallPlatform()
    private val events = RecordingCallEvents()
    private val callAudio = TelecomCallAudio(platform, scope, "OffTopic")

    @After
    fun tearDown() {
        callAudio.stop()
        scope.cancel()
    }

    private fun eventually(condition: () -> Boolean) {
        val deadline = System.nanoTime() + WAIT_NANOS
        while (!condition() && System.nanoTime() < deadline) {
            Thread.sleep(2)
        }
        assertTrue(condition())
    }

    @Test(timeout = 10_000)
    fun `registers a system call routed to the intercom`() {
        platform.available.value = listOf(EARPIECE, SPEAKER, HEADSET, INTERCOM)

        val start = callAudio.start(events)

        assertEquals(CallStart(AudioRouteMessage.BLUETOOTH_HEADSET, systemCall = true), start)
        assertEquals(listOf("OffTopic"), platform.names.toList())
        assertEquals(EndpointType.BLUETOOTH, platform.requests.first())
    }

    @Test(timeout = 10_000)
    fun `prefers a wired headset, then the loudspeaker`() {
        platform.available.value = listOf(EARPIECE, SPEAKER, HEADSET)
        assertEquals(AudioRouteMessage.WIRED_HEADSET, callAudio.start(events).route)
        callAudio.stop()

        platform.available.value = listOf(EARPIECE, SPEAKER)
        assertEquals(AudioRouteMessage.SPEAKER, callAudio.start(events).route)
    }

    @Test(timeout = 10_000)
    fun `keeps the earpiece when nothing better exists`() {
        platform.available.value = listOf(EARPIECE)

        assertEquals(AudioRouteMessage.EARPIECE, callAudio.start(events).route)
        assertTrue(platform.requests.isEmpty())
    }

    @Test(timeout = 10_000)
    fun `starts on the current route when the requested one does not land`() {
        platform.appliesRequests = false
        val impatient = TelecomCallAudio(platform, scope, "OffTopic", routeSettleMs = 10)

        assertEquals(AudioRouteMessage.EARPIECE, impatient.start(events).route)
        impatient.stop()
    }

    @Test(timeout = 10_000)
    fun `reports route changes`() {
        callAudio.start(events)

        platform.current.value = HEADSET

        eventually { events.routes.contains(AudioRouteMessage.WIRED_HEADSET) }
    }

    @Test(timeout = 10_000)
    fun `moves to the intercom when it reconnects`() {
        callAudio.start(events)

        platform.available.value = listOf(EARPIECE, SPEAKER, INTERCOM)

        eventually { platform.current.value == INTERCOM }
        eventually { events.routes.contains(AudioRouteMessage.BLUETOOTH_HEADSET) }
    }

    @Test(timeout = 10_000)
    fun `reports a call the system ends, but not one it ends itself`() {
        callAudio.start(events)
        callAudio.stop()
        assertEquals(0, events.ends)
        assertEquals(1, platform.disconnects)

        callAudio.start(events)
        runBlocking { platform.endFromSystem() }

        runBlocking { withTimeout(WAIT_MS) { events.firstEnd.await() } }
        assertEquals(1, events.ends)
    }

    @Test(timeout = 10_000)
    fun `reports holds and resumes`() {
        callAudio.start(events)

        runBlocking {
            platform.putOnHold()
            platform.resume()
        }

        assertEquals(listOf(true, false), events.holds.toList())
    }

    @Test(timeout = 10_000)
    fun `fails when the system refuses the call`() {
        platform.refusal = IllegalStateException("no Telecom")

        assertFailsWith<IllegalStateException> { callAudio.start(events) }
        callAudio.stop() // nothing left to stop
    }

    @Test(timeout = 10_000)
    fun `fails and hangs up when the call cannot become active`() {
        platform.activates = false

        assertFailsWith<IllegalStateException> { callAudio.start(events) }
        assertEquals(1, platform.disconnects)
    }

    @Test(timeout = 10_000)
    fun `gives up when the system never answers`() {
        platform.answers = false
        val impatient = TelecomCallAudio(platform, scope, "OffTopic", startTimeoutMs = 20, stopTimeoutMs = 20)

        assertFailsWith<Exception> { impatient.start(events) }
        impatient.stop() // already cleaned up by the failed start
        assertEquals(0, platform.disconnects)
    }

    @Test(timeout = 10_000)
    fun `refuses a second call`() {
        callAudio.start(events)

        assertFailsWith<IllegalStateException> { callAudio.start(events) }
    }

    @Test
    fun `stop without a call does nothing`() {
        callAudio.stop()

        assertEquals(0, platform.disconnects)
    }

    @Test
    fun `names the route of every endpoint`() {
        mapOf(
            EndpointType.BLUETOOTH to AudioRouteMessage.BLUETOOTH_HEADSET,
            EndpointType.WIRED_HEADSET to AudioRouteMessage.WIRED_HEADSET,
            EndpointType.SPEAKER to AudioRouteMessage.SPEAKER,
            EndpointType.EARPIECE to AudioRouteMessage.EARPIECE,
            EndpointType.OTHER to AudioRouteMessage.UNKNOWN,
        ).forEach { (type, route) -> assertEquals(route, TelecomCallAudio.routeOf(CallEndpoint(type))) }
    }

    private companion object {
        const val WAIT_MS = 5_000L
        const val WAIT_NANOS = WAIT_MS * 1_000_000
    }
}
