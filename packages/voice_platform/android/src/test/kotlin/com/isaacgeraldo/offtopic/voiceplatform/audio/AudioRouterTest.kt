package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

class AudioRouterFactoryTest {
    private val audio = FakeAudioManagerFacade()

    @Test
    fun `API 29 and 30 use the speakerphone router`() {
        listOf(29, 30).forEach {
            assertIs<LegacySpeakerRouter>(AudioRouterFactory.create(SdkLevel(it), audio))
        }
    }

    @Test
    fun `API 31 and later use communication devices`() {
        listOf(31, 34, 37).forEach {
            assertIs<CommunicationDeviceRouter>(AudioRouterFactory.create(SdkLevel(it), audio))
        }
    }
}

class CommunicationDeviceRouterTest {
    private val audio = FakeAudioManagerFacade().apply { mode = AudioManager.MODE_RINGTONE }
    private val router = CommunicationDeviceRouter(audio)
    private val speaker = AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
    private val earpiece = AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
    private val headset = AudioOutput(AudioDeviceInfo.TYPE_WIRED_HEADSET)

    @Test
    fun `prefers a wired headset`() {
        audio.communicationDevices = listOf(earpiece, speaker, headset)

        assertEquals(AudioRouteMessage.WIRED_HEADSET, router.start())
        assertEquals(headset, audio.communicationDevice)
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audio.mode)
    }

    @Test
    fun `falls back to the loudspeaker`() {
        audio.communicationDevices = listOf(earpiece, speaker)

        assertEquals(AudioRouteMessage.SPEAKER, router.start())
        assertEquals(speaker, audio.communicationDevice)
    }

    @Test
    fun `reports an unknown route when nothing suits`() {
        audio.communicationDevices = listOf(earpiece)

        assertEquals(AudioRouteMessage.UNKNOWN, router.start())
        assertNull(audio.communicationDevice)
    }

    @Test
    fun `reports an unknown route when the system refuses`() {
        audio.communicationDevices = listOf(speaker)
        audio.acceptCommunicationDevice = false

        assertEquals(AudioRouteMessage.UNKNOWN, router.start())
        assertEquals(0, audio.openListeners)
    }

    // The timeout only bounds a failure: the route change releases the wait.
    @Test(timeout = 5_000)
    fun `waits until the system applies the route`() {
        audio.communicationDevices = listOf(speaker)
        audio.appliesRouteAtOnce = false
        audio.routeChanges = listOf(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        val patient = CommunicationDeviceRouter(audio, settleTimeoutMs = 60_000)

        assertEquals(AudioRouteMessage.SPEAKER, patient.start())
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `starts anyway when the route does not land in time`() {
        audio.communicationDevices = listOf(speaker)
        audio.appliesRouteAtOnce = false
        val impatient = CommunicationDeviceRouter(audio, settleTimeoutMs = 0)

        assertEquals(AudioRouteMessage.SPEAKER, impatient.start())
        assertEquals(speaker, audio.communicationDevice)
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `stop clears the device and restores the mode`() {
        audio.communicationDevices = listOf(speaker)
        router.start()

        router.stop()

        assertNull(audio.communicationDevice)
        assertEquals(1, audio.cleared)
        assertEquals(AudioManager.MODE_RINGTONE, audio.mode)
    }
}

class LegacySpeakerRouterTest {
    private val audio = FakeAudioManagerFacade()
    private val router = LegacySpeakerRouter(audio)

    @Test
    fun `turns the speakerphone on without a headset`() {
        audio.outputs = listOf(AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE))

        assertEquals(AudioRouteMessage.SPEAKER, router.start())
        assertEquals(true, audio.isSpeakerphoneOn)
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audio.mode)
    }

    @Test
    fun `leaves the speakerphone off with a USB headset`() {
        audio.isSpeakerphoneOn = true
        audio.outputs = listOf(AudioOutput(AudioDeviceInfo.TYPE_USB_HEADSET))

        assertEquals(AudioRouteMessage.WIRED_HEADSET, router.start())
        assertEquals(false, audio.isSpeakerphoneOn)
    }

    @Test
    fun `stop restores the speakerphone and the mode`() {
        audio.isSpeakerphoneOn = false
        router.start()

        router.stop()

        assertEquals(false, audio.isSpeakerphoneOn)
        assertEquals(AudioManager.MODE_NORMAL, audio.mode)
    }
}
