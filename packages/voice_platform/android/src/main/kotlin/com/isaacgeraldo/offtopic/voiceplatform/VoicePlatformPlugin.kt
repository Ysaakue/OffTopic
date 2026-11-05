package com.isaacgeraldo.offtopic.voiceplatform

import android.content.Context
import android.media.AudioManager
import com.isaacgeraldo.offtopic.voiceplatform.audio.AndroidAudioManagerFacade
import com.isaacgeraldo.offtopic.voiceplatform.call.CallAudioFactory
import com.isaacgeraldo.offtopic.voiceplatform.call.TelecomCallPlatform
import com.isaacgeraldo.offtopic.voiceplatform.core.NativeVoiceCore
import com.isaacgeraldo.offtopic.voiceplatform.core.VoiceCoreBridge
import com.isaacgeraldo.offtopic.voiceplatform.generated.VoicePlatformHostApi
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateEventChannel
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateStreamHandler
import com.isaacgeraldo.offtopic.voiceplatform.room.RoomController
import com.isaacgeraldo.offtopic.voiceplatform.system.ActivityKeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.AndroidDeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Flutter entry point: wires the Pigeon channels to the Android implementation. */
class VoicePlatformPlugin internal constructor(
    private val keepScreenOn: ActivityKeepScreenOnController,
    private val coreFactory: () -> VoiceCoreBridge,
) : FlutterPlugin,
    ActivityAware {
    private var routeExecutor: ExecutorService? = null
    private var room: RoomController? = null
    private var callScope: CoroutineScope? = null

    /** Used by the Flutter plugin registrant. */
    constructor() : this(ActivityKeepScreenOnController(), ::NativeVoiceCore)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val sdkLevel = SdkLevel.current()
        val audioManager = binding.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val audio = AndroidAudioManagerFacade(binding.applicationContext, audioManager)
        val core by lazy(coreFactory)
        val executor = Executors.newSingleThreadExecutor()
        routeExecutor = executor
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        callScope = scope
        val room =
            RoomController(
                core = { core },
                callAudio =
                    CallAudioFactory.create(
                        sdkLevel = sdkLevel,
                        calls = TelecomCallPlatform(binding.applicationContext),
                        audio = audio,
                        callScope = scope,
                        routeExecutor = executor,
                    ),
                eventExecutor = executor,
            )
        this.room = room
        val api =
            VoicePlatformApiImpl(
                sdkLevel = sdkLevel,
                deviceInfo = AndroidDeviceInfoProvider(),
                keepScreenOn = keepScreenOn,
                room = room,
                roomDispatcher = Dispatchers.IO,
            )
        VoicePlatformHostApi.setUp(binding.binaryMessenger, api)
        WatchPlatformStateStreamHandler.register(
            binding.binaryMessenger,
            PlatformStateStreamHandler(room, binding.applicationContext.mainExecutor),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        VoicePlatformHostApi.setUp(binding.binaryMessenger, null)
        WatchPlatformStateEventChannel(binding.binaryMessenger).setStreamHandler(null)
        // Until the foreground service owns the room (phase 4), it ends with the engine;
        // stopping it also ends the call and the device watch that use the executor.
        room?.stop()
        room = null
        callScope?.cancel()
        callScope = null
        routeExecutor?.shutdown()
        routeExecutor = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = keepScreenOn.attach(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = keepScreenOn.detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        keepScreenOn.attach(binding.activity)

    override fun onDetachedFromActivity() = keepScreenOn.detach()
}
