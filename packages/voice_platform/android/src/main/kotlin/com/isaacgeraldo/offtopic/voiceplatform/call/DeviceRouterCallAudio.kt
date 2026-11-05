package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouter
import java.util.concurrent.Executor

/**
 * [CallAudio] without the system's call registry: the phase 1 routing
 * (AudioManager call mode plus communication device or Bluetooth SCO), which
 * follows device changes itself. The fallback when Telecom refuses the call.
 *
 * @param watchDevices calls its listener on every device change until closed.
 * @param routeExecutor where a route is re-applied (it may wait for the system).
 */
internal class DeviceRouterCallAudio(
    private val router: AudioRouter,
    private val watchDevices: (() -> Unit) -> AutoCloseable,
    private val routeExecutor: Executor,
) : CallAudio {
    private var watch: AutoCloseable? = null
    private var events: CallEvents? = null

    @Synchronized
    override fun start(events: CallEvents): CallStart {
        val route = router.start()
        this.events = events
        watch = watchDevices { routeExecutor.execute(::refresh) }
        return CallStart(route, systemCall = false)
    }

    @Synchronized
    override fun stop() {
        if (events == null) {
            return
        }
        watch?.close()
        watch = null
        events = null
        router.stop()
    }

    @Synchronized
    private fun refresh() {
        // A change queued before stop() arrives late: nothing to route any more.
        events?.onRouteChanged(router.refresh())
    }
}
