package com.isaacgeraldo.offtopic.voiceplatform.call

import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioManagerFacade
import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouterFactory
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import kotlinx.coroutines.CoroutineScope
import java.util.concurrent.Executor

/** The room's call mode: a system call, with direct routing as the fallback. */
internal object CallAudioFactory {
    const val CALL_NAME = "OffTopic"

    fun create(
        sdkLevel: SdkLevel,
        calls: CallPlatform,
        audio: AudioManagerFacade,
        callScope: CoroutineScope,
        routeExecutor: Executor,
    ): CallAudio =
        FallbackCallAudio(
            primary = TelecomCallAudio(calls, callScope, CALL_NAME),
            fallback =
                DeviceRouterCallAudio(
                    router = AudioRouterFactory.create(sdkLevel, audio),
                    watchDevices = audio::onDevicesChanged,
                    routeExecutor = routeExecutor,
                ),
        )
}
