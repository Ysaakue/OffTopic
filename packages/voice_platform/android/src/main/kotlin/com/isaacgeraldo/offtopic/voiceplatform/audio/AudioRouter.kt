package com.isaacgeraldo.offtopic.voiceplatform.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Puts the phone in call mode and chooses where the room is heard.
 *
 * The core tags its streams as voice communication, which Android routes to
 * the earpiece by default. Preference: the Bluetooth intercom (HFP/SCO), then
 * a wired or USB headset, then the loudspeaker.
 */
internal interface AudioRouter {
    /** Enters call mode, applies the best route and returns it. */
    fun start(): AudioRouteMessage

    /** Re-applies the best route after devices came or went, and returns it. */
    fun refresh(): AudioRouteMessage

    /** Restores what start() changed. */
    fun stop()
}

internal object AudioRouterFactory {
    private const val COMMUNICATION_DEVICE_API = 31

    fun create(
        sdkLevel: SdkLevel,
        audio: AudioManagerFacade,
    ): AudioRouter =
        if (sdkLevel.isAtLeast(COMMUNICATION_DEVICE_API)) {
            CommunicationDeviceRouter(audio)
        } else {
            LegacyScoRouter(audio)
        }
}

// Seen on a Galaxy A54 (Android 16): the speaker route lands about 250 ms
// after setCommunicationDevice. Past this the room starts anyway and the core
// retries a stream start that the late route disconnects.
private const val ROUTE_SETTLE_TIMEOUT_MS = 1_000L

// Bluetooth SCO usually connects in one to two seconds.
private const val SCO_CONNECT_TIMEOUT_MS = 4_000L

internal object AudioDeviceTypes {
    /** The intercom: classic HFP (SCO) or LE Audio (API 31 type, inlined on older APIs). */
    val BLUETOOTH =
        setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
        )

    val HEADSETS =
        setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )

    fun routeOf(type: Int): AudioRouteMessage =
        when (type) {
            in BLUETOOTH -> AudioRouteMessage.BLUETOOTH_HEADSET
            in HEADSETS -> AudioRouteMessage.WIRED_HEADSET
            else -> AudioRouteMessage.SPEAKER
        }
}

/**
 * API 31+: AudioManager.setCommunicationDevice. A Bluetooth device as the
 * communication device brings up its SCO link by itself.
 *
 * @param settleTimeoutMs how long a route change waits for the system to apply it.
 */
internal class CommunicationDeviceRouter(
    private val audio: AudioManagerFacade,
    private val settleTimeoutMs: Long = ROUTE_SETTLE_TIMEOUT_MS,
) : AudioRouter {
    private var previousMode = AudioManager.MODE_NORMAL

    override fun start(): AudioRouteMessage {
        previousMode = audio.mode
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        return applyBestRoute()
    }

    override fun refresh(): AudioRouteMessage = applyBestRoute()

    override fun stop() {
        audio.clearCommunicationDevice()
        audio.mode = previousMode
    }

    private fun applyBestRoute(): AudioRouteMessage {
        val devices = audio.availableCommunicationDevices()
        val target =
            devices.firstOrNull { it.type in AudioDeviceTypes.BLUETOOTH }
                ?: devices.firstOrNull { it.type in AudioDeviceTypes.HEADSETS }
                ?: devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (target == null || !applyRoute(target)) {
            return AudioRouteMessage.UNKNOWN
        }
        return AudioDeviceTypes.routeOf(target.type)
    }

    // The system applies the route asynchronously. Audio streams opened before
    // it lands are moved to the new device, and AAudio disconnects a stream
    // moved while it starts, so wait (bounded) until the route is in place.
    private fun applyRoute(target: AudioOutput): Boolean {
        val settled = CountDownLatch(1)
        audio
            .onCommunicationDeviceChanged { type ->
                if (type == target.type) {
                    settled.countDown()
                }
            }.use {
                if (!audio.setCommunicationDevice(target)) {
                    return false
                }
                if (audio.communicationDeviceType() != target.type) {
                    settled.await(settleTimeoutMs, TimeUnit.MILLISECONDS)
                }
            }
        return true
    }
}

/**
 * API 29-30: Bluetooth SCO through startBluetoothSco (waiting for the link),
 * otherwise the speakerphone unless a headset is plugged in.
 *
 * @param scoTimeoutMs how long start/refresh waits for the SCO link.
 */
internal class LegacyScoRouter(
    private val audio: AudioManagerFacade,
    private val scoTimeoutMs: Long = SCO_CONNECT_TIMEOUT_MS,
) : AudioRouter {
    private var previousMode = AudioManager.MODE_NORMAL
    private var previousSpeakerphone = false
    private var scoConnected = false

    override fun start(): AudioRouteMessage {
        previousMode = audio.mode
        previousSpeakerphone = audio.isSpeakerphoneOn
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        return applyBestRoute()
    }

    override fun refresh(): AudioRouteMessage = applyBestRoute()

    override fun stop() {
        disconnectSco()
        audio.isSpeakerphoneOn = previousSpeakerphone
        audio.mode = previousMode
    }

    private fun applyBestRoute(): AudioRouteMessage {
        val outputs = audio.outputDevices()
        if (outputs.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO } && connectSco()) {
            audio.isSpeakerphoneOn = false
            return AudioRouteMessage.BLUETOOTH_HEADSET
        }
        disconnectSco()
        val headset = outputs.any { it.type in AudioDeviceTypes.HEADSETS }
        audio.isSpeakerphoneOn = !headset
        return if (headset) AudioRouteMessage.WIRED_HEADSET else AudioRouteMessage.SPEAKER
    }

    @Suppress("DEPRECATION") // the SCO states are the API 29-30 contract
    private fun connectSco(): Boolean {
        if (scoConnected) {
            return true
        }
        val connected = CountDownLatch(1)
        audio
            .onScoAudioStateChanged { state ->
                if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
                    connected.countDown()
                }
            }.use {
                audio.startBluetoothSco()
                audio.isBluetoothScoOn = true
                scoConnected = connected.await(scoTimeoutMs, TimeUnit.MILLISECONDS)
            }
        if (!scoConnected) {
            audio.isBluetoothScoOn = false
            audio.stopBluetoothSco()
        }
        return scoConnected
    }

    private fun disconnectSco() {
        if (scoConnected) {
            audio.isBluetoothScoOn = false
            audio.stopBluetoothSco()
            scoConnected = false
        }
    }
}
