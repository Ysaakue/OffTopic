package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import io.mockk.every
import io.mockk.mockk
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AudioDeviceInfoBuilder
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37])
class AndroidAudioManagerFacadeTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val facade = AndroidAudioManagerFacade(context, audioManager)

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
    fun `watches device changes until closed`() {
        var changes = 0
        val watch = facade.onDevicesChanged { changes++ }
        shadowOf(Looper.getMainLooper()).idle()
        val before = changes

        shadowOf(audioManager).addOutputDevice(device(AudioDeviceInfo.TYPE_BLUETOOTH_SCO), true)
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(changes > before)

        watch.close()
        val afterClose = changes
        shadowOf(audioManager).addOutputDevice(device(AudioDeviceInfo.TYPE_WIRED_HEADSET), true)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(afterClose, changes)
    }

    @Test
    @Suppress("DEPRECATION")
    fun `drives the legacy Bluetooth SCO link`() {
        facade.startBluetoothSco()
        facade.isBluetoothScoOn = true
        assertTrue(facade.isBluetoothScoOn)

        facade.isBluetoothScoOn = false
        facade.stopBluetoothSco()
        assertFalse(audioManager.isBluetoothScoOn)
    }

    @Test
    @Suppress("DEPRECATION")
    fun `reports new SCO states but not the one replayed on registration`() {
        context.sendStickyBroadcast(scoState(AudioManager.SCO_AUDIO_STATE_CONNECTED))
        val states = mutableListOf<Int>()
        val watch = facade.onScoAudioStateChanged { states += it }
        shadowOf(Looper.getMainLooper()).idle()

        context.sendBroadcast(scoState(AudioManager.SCO_AUDIO_STATE_DISCONNECTED))
        shadowOf(Looper.getMainLooper()).idle()
        watch.close()
        context.sendBroadcast(scoState(AudioManager.SCO_AUDIO_STATE_CONNECTED))
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(listOf(AudioManager.SCO_AUDIO_STATE_DISCONNECTED), states)
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

    private fun device(type: Int): AudioDeviceInfo = AudioDeviceInfoBuilder.newBuilder().setType(type).build()

    private fun scoState(state: Int) =
        Intent(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED).putExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, state)
}
