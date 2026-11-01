package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.AudioRouteMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.PigeonEventSink
import com.isaacgeraldo.offtopic.voiceplatform.generated.PlatformStateMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateStreamHandler
import com.isaacgeraldo.offtopic.voiceplatform.generated.WifiStateMessage

/**
 * Streams the platform state (service, audio route, Wi-Fi) to Dart.
 *
 * Until the foreground service exists (phase 4) the state is always idle, and
 * it is emitted once to every new listener.
 */
internal class PlatformStateStreamHandler : WatchPlatformStateStreamHandler() {
    override fun onListen(
        p0: Any?,
        sink: PigeonEventSink<PlatformStateMessage>,
    ) {
        sink.success(IDLE_STATE)
    }

    companion object {
        val IDLE_STATE =
            PlatformStateMessage(
                serviceRunning = false,
                audioRoute = AudioRouteMessage.UNKNOWN,
                wifiState = WifiStateMessage.UNKNOWN,
            )
    }
}
