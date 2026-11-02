package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.media.AudioManager

internal class FakeAudioManagerFacade : AudioManagerFacade {
    override var mode: Int = AudioManager.MODE_NORMAL
    override var isSpeakerphoneOn: Boolean = false
    var outputs: List<AudioOutput> = emptyList()
    var communicationDevices: List<AudioOutput> = emptyList()
    var acceptCommunicationDevice = true

    /** The last device accepted by setCommunicationDevice. */
    var communicationDevice: AudioOutput? = null

    /** When false, the route is not in place yet when setCommunicationDevice returns. */
    var appliesRouteAtOnce = true

    /** Device types announced to the listeners while setCommunicationDevice runs. */
    var routeChanges: List<Int?> = emptyList()
    var currentRouteType: Int? = null
    var cleared = 0
    private val listeners = mutableListOf<(Int?) -> Unit>()
    val openListeners: Int
        get() = listeners.size

    override fun outputDevices(): List<AudioOutput> = outputs

    override fun availableCommunicationDevices(): List<AudioOutput> = communicationDevices

    override fun setCommunicationDevice(device: AudioOutput): Boolean {
        if (!acceptCommunicationDevice) {
            return false
        }
        communicationDevice = device
        if (appliesRouteAtOnce) {
            currentRouteType = device.type
        }
        routeChanges.forEach { type -> listeners.toList().forEach { it(type) } }
        return true
    }

    override fun clearCommunicationDevice() {
        communicationDevice = null
        currentRouteType = null
        cleared++
    }

    override fun communicationDeviceType(): Int? = currentRouteType

    override fun onCommunicationDeviceChanged(listener: (Int?) -> Unit): AutoCloseable {
        listeners += listener
        return AutoCloseable { listeners -= listener }
    }
}
