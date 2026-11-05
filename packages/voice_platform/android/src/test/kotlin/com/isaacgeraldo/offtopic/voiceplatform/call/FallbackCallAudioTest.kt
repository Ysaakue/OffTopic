package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.audio.FakeAudioManagerFacade
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class FallbackCallAudioTest {
    private val events = RecordingCallEvents()
    private val primary = ScriptedCallAudio(CallStart(AudioRouteMessage.BLUETOOTH_HEADSET, systemCall = true))
    private val fallback = ScriptedCallAudio(CallStart(AudioRouteMessage.SPEAKER, systemCall = false))
    private val callAudio = FallbackCallAudio(primary, fallback)

    @Test
    fun `uses the system call when it is accepted`() {
        assertEquals(primary.result, callAudio.start(events))

        callAudio.stop()

        assertEquals(1, primary.stops)
        assertEquals(0, fallback.starts)
    }

    @Test
    fun `falls back to direct routing when the system refuses the call`() {
        primary.failure = IllegalStateException("refused")

        assertEquals(fallback.result, callAudio.start(events))

        callAudio.stop()
        callAudio.stop()
        assertEquals(1, fallback.stops)
        assertEquals(0, primary.stops)
    }

    @Test
    fun `the factory builds a system call with direct routing behind it`() {
        val created =
            CallAudioFactory.create(
                sdkLevel = SdkLevel(34),
                calls = FakeCallPlatform(),
                audio = FakeAudioManagerFacade(),
                callScope = CoroutineScope(Dispatchers.Unconfined),
                routeExecutor = Runnable::run,
            )

        assertIs<FallbackCallAudio>(created)
    }

    private class ScriptedCallAudio(
        val result: CallStart,
    ) : CallAudio {
        var failure: Exception? = null
        var starts = 0
        var stops = 0

        override fun start(events: CallEvents): CallStart {
            starts++
            failure?.let { throw it }
            return result
        }

        override fun stop() {
            stops++
        }
    }
}
