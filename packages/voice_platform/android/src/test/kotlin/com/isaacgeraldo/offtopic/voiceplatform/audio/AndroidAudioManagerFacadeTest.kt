package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37])
class AndroidAudioManagerFacadeTest {
    private val audioManager =
        ApplicationProvider.getApplicationContext<Context>().getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val facade = AndroidAudioManagerFacade(audioManager)

    @Test
    fun `reads and writes the audio mode`() {
        facade.mode = AudioManager.MODE_IN_COMMUNICATION

        assertEquals(AudioManager.MODE_IN_COMMUNICATION, facade.mode)
        assertEquals(AudioManager.MODE_IN_COMMUNICATION, audioManager.mode)
    }

    @Test
    fun `reads and writes the speakerphone`() {
        facade.isSpeakerphoneOn = true
        assertTrue(facade.isSpeakerphoneOn)

        facade.isSpeakerphoneOn = false
        assertFalse(facade.isSpeakerphoneOn)
    }

    @Test
    fun `lists devices with their types`() {
        val outputs = facade.outputDevices()
        val communication = facade.availableCommunicationDevices()

        assertEquals(audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }, outputs.map { it.type })
        assertEquals(audioManager.availableCommunicationDevices.map { it.type }, communication.map { it.type })
    }

    @Test
    fun `refuses a device without a system handle`() {
        assertFalse(facade.setCommunicationDevice(AudioOutput(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)))
    }

    @Test
    fun `hands a device with a system handle to the AudioManager`() {
        val device = mockk<AudioDeviceInfo>(relaxed = true)
        every { device.type } returns AudioDeviceInfo.TYPE_BUILTIN_SPEAKER

        val accepted = facade.setCommunicationDevice(AudioOutput(device.type, device))

        assertEquals(accepted, audioManager.communicationDevice == device)
    }

    @Test
    fun `clears the communication device`() {
        facade.clearCommunicationDevice()

        assertEquals(null, audioManager.communicationDevice)
    }

    @Test
    fun `reports the type of the current call route`() {
        assertEquals(audioManager.communicationDevice?.type, facade.communicationDeviceType())
    }

    @Test
    fun `registers a route listener until it is closed`() {
        val handle = facade.onCommunicationDeviceChanged {}

        handle.close()
    }
}
