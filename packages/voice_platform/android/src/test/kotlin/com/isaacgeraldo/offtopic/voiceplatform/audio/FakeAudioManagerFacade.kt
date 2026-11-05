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
    private val routeListeners = mutableListOf<(Int?) -> Unit>()
    val openListeners: Int
        get() = routeListeners.size + scoListeners.size + deviceListeners.size

    // Legacy SCO (API 29-30).
    override var isBluetoothScoOn: Boolean = false

    /** SCO states announced to the listeners while startBluetoothSco runs. */
    var scoStates: List<Int> = emptyList()
    var scoStarts = 0
    var scoStops = 0
    private val scoListeners = mutableListOf<(Int) -> Unit>()

    private val deviceListeners = mutableListOf<() -> Unit>()

    /** Simulates a device being plugged in or removed. */
    fun changeDevices() = deviceListeners.toList().forEach { it() }

    override fun outputDevices(): List<AudioOutput> = outputs

    override fun onDevicesChanged(listener: () -> Unit): AutoCloseable {
        deviceListeners += listener
        return AutoCloseable { deviceListeners -= listener }
    }

    override fun availableCommunicationDevices(): List<AudioOutput> = communicationDevices

    override fun setCommunicationDevice(device: AudioOutput): Boolean {
        if (!acceptCommunicationDevice) {
            return false
        }
        communicationDevice = device
        if (appliesRouteAtOnce) {
            currentRouteType = device.type
        }
        routeChanges.forEach { type -> routeListeners.toList().forEach { it(type) } }
        return true
    }

    override fun clearCommunicationDevice() {
        communicationDevice = null
        currentRouteType = null
        cleared++
    }

    override fun communicationDeviceType(): Int? = currentRouteType

    override fun onCommunicationDeviceChanged(listener: (Int?) -> Unit): AutoCloseable {
        routeListeners += listener
        return AutoCloseable { routeListeners -= listener }
    }

    override fun startBluetoothSco() {
        scoStarts++
        scoStates.forEach { state -> scoListeners.toList().forEach { it(state) } }
    }

    override fun stopBluetoothSco() {
        scoStops++
    }

    override fun onScoAudioStateChanged(listener: (Int) -> Unit): AutoCloseable {
        scoListeners += listener
        return AutoCloseable { scoListeners -= listener }
    }
}
