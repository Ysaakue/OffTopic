package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.annotation.TargetApi
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper

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

    /** Calls [listener] each time an audio device is added or removed, until closed. */
    fun onDevicesChanged(listener: () -> Unit): AutoCloseable

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

    /** API 29-30: Bluetooth SCO, the intercom's call audio link. */
    fun startBluetoothSco()

    /** API 29-30. */
    fun stopBluetoothSco()

    /** API 29-30. */
    var isBluetoothScoOn: Boolean

    /**
     * API 29-30: calls [listener] with every new AudioManager.SCO_AUDIO_STATE_*
     * (not the last state the system kept), until the returned handle is closed.
     */
    fun onScoAudioStateChanged(listener: (Int) -> Unit): AutoCloseable
}

internal class AndroidAudioManagerFacade(
    private val context: Context,
    private val audioManager: AudioManager,
) : AudioManagerFacade {
    private val callbackHandler = Handler(Looper.getMainLooper())

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

    override fun onDevicesChanged(listener: () -> Unit): AutoCloseable {
        val callback =
            object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = listener()

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = listener()
            }
        audioManager.registerAudioDeviceCallback(callback, callbackHandler)
        return AutoCloseable { audioManager.unregisterAudioDeviceCallback(callback) }
    }

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

    @Suppress("DEPRECATION") // API 29-30 only; API 31+ routes through setCommunicationDevice
    override fun startBluetoothSco() = audioManager.startBluetoothSco()

    @Suppress("DEPRECATION")
    override fun stopBluetoothSco() = audioManager.stopBluetoothSco()

    @Suppress("DEPRECATION")
    override var isBluetoothScoOn: Boolean
        get() = audioManager.isBluetoothScoOn
        set(value) {
            audioManager.isBluetoothScoOn = value
        }

    @Suppress("DEPRECATION") // API 29-30 only
    override fun onScoAudioStateChanged(listener: (Int) -> Unit): AutoCloseable {
        val receiver =
            object : BroadcastReceiver() {
                override fun onReceive(
                    receiverContext: Context,
                    intent: Intent,
                ) {
                    // The broadcast is sticky: the state replayed on registration is stale.
                    if (!isInitialStickyBroadcast) {
                        val state =
                            intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, AudioManager.SCO_AUDIO_STATE_ERROR)
                        listener(state)
                    }
                }
            }
        context.registerReceiver(receiver, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
        return AutoCloseable { context.unregisterReceiver(receiver) }
    }
}
