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
 * the earpiece by default. Phase 1 (no Bluetooth yet) prefers a wired or USB
 * headset and falls back to the loudspeaker; phase 2 adds the intercom (SCO).
 */
internal interface AudioRouter {
    /** Applies the route and returns it. */
    fun start(): AudioRouteMessage

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
            LegacySpeakerRouter(audio)
        }
}

// Seen on a Galaxy A54 (Android 16): the speaker route lands about 250 ms
// after setCommunicationDevice. Past this the room starts anyway and the core
// retries a stream start that the late route disconnects.
private const val ROUTE_SETTLE_TIMEOUT_MS = 1_000L

internal object AudioDeviceTypes {
    val HEADSETS =
        setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )
}

/**
 * API 31+: AudioManager.setCommunicationDevice.
 *
 * @param settleTimeoutMs how long start() waits for the system to apply the route.
 */
internal class CommunicationDeviceRouter(
    private val audio: AudioManagerFacade,
    private val settleTimeoutMs: Long = ROUTE_SETTLE_TIMEOUT_MS,
) : AudioRouter {
    private var previousMode = AudioManager.MODE_NORMAL

    override fun start(): AudioRouteMessage {
        previousMode = audio.mode
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        val devices = audio.availableCommunicationDevices()
        val target =
            devices.firstOrNull { it.type in AudioDeviceTypes.HEADSETS }
                ?: devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (target == null || !applyRoute(target)) {
            return AudioRouteMessage.UNKNOWN
        }
        return if (target.type in AudioDeviceTypes.HEADSETS) {
            AudioRouteMessage.WIRED_HEADSET
        } else {
            AudioRouteMessage.SPEAKER
        }
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

    override fun stop() {
        audio.clearCommunicationDevice()
        audio.mode = previousMode
    }
}

/** API 29-30: speakerphone on unless a headset is plugged in. */
internal class LegacySpeakerRouter(
    private val audio: AudioManagerFacade,
) : AudioRouter {
    private var previousMode = AudioManager.MODE_NORMAL
    private var previousSpeakerphone = false

    override fun start(): AudioRouteMessage {
        previousMode = audio.mode
        previousSpeakerphone = audio.isSpeakerphoneOn
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        val headset = audio.outputDevices().any { it.type in AudioDeviceTypes.HEADSETS }
        audio.isSpeakerphoneOn = !headset
        return if (headset) AudioRouteMessage.WIRED_HEADSET else AudioRouteMessage.SPEAKER
    }

    override fun stop() {
        audio.isSpeakerphoneOn = previousSpeakerphone
        audio.mode = previousMode
    }
}
