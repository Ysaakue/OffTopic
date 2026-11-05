package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

private val SPEAKER = AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
private val EARPIECE = AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
private val HEADSET = AudioOutput(AudioDeviceInfo.TYPE_WIRED_HEADSET)
private val INTERCOM = AudioOutput(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
private val LE_AUDIO = AudioOutput(AudioDeviceInfo.TYPE_BLE_HEADSET)

class AudioRouterFactoryTest {
    private val audio = FakeAudioManagerFacade()

    @Test
    fun `API 29 and 30 use the legacy SCO router`() {
        listOf(29, 30).forEach {
            assertIs<LegacyScoRouter>(AudioRouterFactory.create(SdkLevel(it), audio))
        }
    }

    @Test
    fun `API 31 and later use communication devices`() {
        listOf(31, 34, 37).forEach {
            assertIs<CommunicationDeviceRouter>(AudioRouterFactory.create(SdkLevel(it), audio))
        }
    }
}

class AudioDeviceTypesTest {
    @Test
    fun `names the route of every device type`() {
        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, AudioDeviceTypes.routeOf(INTERCOM.type))
        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, AudioDeviceTypes.routeOf(LE_AUDIO.type))
        assertEquals(AudioRouteMessage.WIRED_HEADSET, AudioDeviceTypes.routeOf(HEADSET.type))
        assertEquals(AudioRouteMessage.SPEAKER, AudioDeviceTypes.routeOf(SPEAKER.type))
    }
}

class CommunicationDeviceRouterTest {
    private val audio = FakeAudioManagerFacade().apply { mode = AudioManager.MODE_RINGTONE }
    private val router = CommunicationDeviceRouter(audio)

    @Test
    fun `prefers the Bluetooth intercom`() {
        audio.communicationDevices = listOf(EARPIECE, SPEAKER, HEADSET, INTERCOM)

        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, router.start())
        assertEquals(INTERCOM, audio.communicationDevice)
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audio.mode)
    }

    @Test
    fun `accepts an LE Audio headset as the intercom`() {
        audio.communicationDevices = listOf(SPEAKER, LE_AUDIO)

        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, router.start())
    }

    @Test
    fun `prefers a wired headset to the loudspeaker`() {
        audio.communicationDevices = listOf(EARPIECE, SPEAKER, HEADSET)

        assertEquals(AudioRouteMessage.WIRED_HEADSET, router.start())
        assertEquals(HEADSET, audio.communicationDevice)
    }

    @Test
    fun `falls back to the loudspeaker`() {
        audio.communicationDevices = listOf(EARPIECE, SPEAKER)

        assertEquals(AudioRouteMessage.SPEAKER, router.start())
        assertEquals(SPEAKER, audio.communicationDevice)
    }

    @Test
    fun `reports an unknown route when nothing suits`() {
        audio.communicationDevices = listOf(EARPIECE)

        assertEquals(AudioRouteMessage.UNKNOWN, router.start())
        assertNull(audio.communicationDevice)
    }

    @Test
    fun `reports an unknown route when the system refuses`() {
        audio.communicationDevices = listOf(SPEAKER)
        audio.acceptCommunicationDevice = false

        assertEquals(AudioRouteMessage.UNKNOWN, router.start())
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `refresh moves to the intercom when it connects and back when it drops out`() {
        audio.communicationDevices = listOf(SPEAKER)
        router.start()

        audio.communicationDevices = listOf(SPEAKER, INTERCOM)
        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, router.refresh())
        assertEquals(INTERCOM, audio.communicationDevice)

        audio.communicationDevices = listOf(SPEAKER)
        assertEquals(AudioRouteMessage.SPEAKER, router.refresh())
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audio.mode)
    }

    // The timeout only bounds a failure: the route change releases the wait.
    @Test(timeout = 5_000)
    fun `waits until the system applies the route`() {
        audio.communicationDevices = listOf(SPEAKER)
        audio.appliesRouteAtOnce = false
        audio.routeChanges = listOf(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
        val patient = CommunicationDeviceRouter(audio, settleTimeoutMs = 60_000)

        assertEquals(AudioRouteMessage.SPEAKER, patient.start())
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `starts anyway when the route does not land in time`() {
        audio.communicationDevices = listOf(SPEAKER)
        audio.appliesRouteAtOnce = false
        val impatient = CommunicationDeviceRouter(audio, settleTimeoutMs = 0)

        assertEquals(AudioRouteMessage.SPEAKER, impatient.start())
        assertEquals(SPEAKER, audio.communicationDevice)
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `stop clears the device and restores the mode`() {
        audio.communicationDevices = listOf(SPEAKER)
        router.start()

        router.stop()

        assertNull(audio.communicationDevice)
        assertEquals(1, audio.cleared)
        assertEquals(AudioManager.MODE_RINGTONE, audio.mode)
    }
}

class LegacyScoRouterTest {
    private val audio = FakeAudioManagerFacade()
    private val router = LegacyScoRouter(audio, scoTimeoutMs = 0)

    @Test
    fun `turns the speakerphone on without a headset`() {
        audio.outputs = listOf(EARPIECE)

        assertEquals(AudioRouteMessage.SPEAKER, router.start())
        assertEquals(true, audio.isSpeakerphoneOn)
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audio.mode)
        assertEquals(0, audio.scoStarts)
    }

    @Test
    fun `leaves the speakerphone off with a USB headset`() {
        audio.isSpeakerphoneOn = true
        audio.outputs = listOf(AudioOutput(AudioDeviceInfo.TYPE_USB_HEADSET))

        assertEquals(AudioRouteMessage.WIRED_HEADSET, router.start())
        assertEquals(false, audio.isSpeakerphoneOn)
    }

    @Test(timeout = 5_000)
    fun `connects the intercom over SCO`() {
        audio.outputs = listOf(SPEAKER, INTERCOM)
        audio.scoStates = listOf(AudioManager.SCO_AUDIO_STATE_CONNECTING, AudioManager.SCO_AUDIO_STATE_CONNECTED)
        val patient = LegacyScoRouter(audio, scoTimeoutMs = 60_000)

        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, patient.start())
        assertEquals(true, audio.isBluetoothScoOn)
        assertEquals(false, audio.isSpeakerphoneOn)
        assertEquals(0, audio.openListeners)
    }

    @Test
    fun `falls back to the loudspeaker when SCO does not connect`() {
        audio.outputs = listOf(SPEAKER, INTERCOM)
        audio.scoStates = listOf(AudioManager.SCO_AUDIO_STATE_ERROR)

        assertEquals(AudioRouteMessage.SPEAKER, router.start())
        assertEquals(false, audio.isBluetoothScoOn)
        assertEquals(1, audio.scoStops)
        assertEquals(true, audio.isSpeakerphoneOn)
    }

    @Test
    fun `keeps a connected SCO link on refresh and drops it with the intercom`() {
        audio.outputs = listOf(SPEAKER, INTERCOM)
        audio.scoStates = listOf(AudioManager.SCO_AUDIO_STATE_CONNECTED)
        router.start()

        assertEquals(AudioRouteMessage.BLUETOOTH_HEADSET, router.refresh())
        assertEquals(1, audio.scoStarts)

        audio.outputs = listOf(SPEAKER)
        assertEquals(AudioRouteMessage.SPEAKER, router.refresh())
        assertEquals(false, audio.isBluetoothScoOn)
        assertEquals(1, audio.scoStops)
    }

    @Test
    fun `stop disconnects SCO and restores the speakerphone and the mode`() {
        audio.outputs = listOf(INTERCOM)
        audio.scoStates = listOf(AudioManager.SCO_AUDIO_STATE_CONNECTED)
        audio.isSpeakerphoneOn = false
        router.start()

        router.stop()

        assertEquals(false, audio.isBluetoothScoOn)
        assertEquals(1, audio.scoStops)
        assertEquals(false, audio.isSpeakerphoneOn)
        assertEquals(AudioManager.MODE_NORMAL, audio.mode)
    }

    @Test
    fun `stop without SCO leaves the Bluetooth alone`() {
        audio.outputs = listOf(EARPIECE)
        router.start()

        router.stop()

        assertEquals(0, audio.scoStops)
    }
}
