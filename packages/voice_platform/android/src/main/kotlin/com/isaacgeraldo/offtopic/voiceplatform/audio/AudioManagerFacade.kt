package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.annotation.TargetApi
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

/** An output device as the routers see it: its AudioDeviceInfo type, plus the handle. */
internal data class AudioOutput(
    val type: Int,
    val handle: AudioDeviceInfo? = null,
)

/**
 * Thin view of [AudioManager]: no logic, so the routers above it are plain
 * JVM classes tested with fakes.
 */
internal interface AudioManagerFacade {
    var mode: Int
    var isSpeakerphoneOn: Boolean

    fun outputDevices(): List<AudioOutput>

    /** API 31+. */
    fun availableCommunicationDevices(): List<AudioOutput>

    /** API 31+. */
    fun setCommunicationDevice(device: AudioOutput): Boolean

    /** API 31+. */
    fun clearCommunicationDevice()

    /** API 31+: type of the device calls are routed to now, or null. */
    fun communicationDeviceType(): Int?

    /**
     * API 31+: calls [listener] with the new device type each time the call
     * route changes (on a system thread), until the returned handle is closed.
     */
    fun onCommunicationDeviceChanged(listener: (Int?) -> Unit): AutoCloseable
}

internal class AndroidAudioManagerFacade(
    private val audioManager: AudioManager,
) : AudioManagerFacade {
    override var mode: Int
        get() = audioManager.mode
        set(value) {
            audioManager.mode = value
        }

    @Suppress("DEPRECATION") // the API 29-30 route; API 31+ uses communication devices
    override var isSpeakerphoneOn: Boolean
        get() = audioManager.isSpeakerphoneOn
        set(value) {
            audioManager.isSpeakerphoneOn = value
        }

    override fun outputDevices(): List<AudioOutput> =
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { AudioOutput(it.type, it) }

    @TargetApi(Build.VERSION_CODES.S)
    override fun availableCommunicationDevices(): List<AudioOutput> =
        audioManager.availableCommunicationDevices.map { AudioOutput(it.type, it) }

    @TargetApi(Build.VERSION_CODES.S)
    override fun setCommunicationDevice(device: AudioOutput): Boolean =
        device.handle?.let { audioManager.setCommunicationDevice(it) } ?: false

    @TargetApi(Build.VERSION_CODES.S)
    override fun clearCommunicationDevice() = audioManager.clearCommunicationDevice()

    @TargetApi(Build.VERSION_CODES.S)
    override fun communicationDeviceType(): Int? = audioManager.communicationDevice?.type

    @TargetApi(Build.VERSION_CODES.S)
    override fun onCommunicationDeviceChanged(listener: (Int?) -> Unit): AutoCloseable {
        val systemListener = AudioManager.OnCommunicationDeviceChangedListener { listener(it?.type) }
        audioManager.addOnCommunicationDeviceChangedListener(Runnable::run, systemListener)
        return AutoCloseable { audioManager.removeOnCommunicationDeviceChangedListener(systemListener) }
    }
}
