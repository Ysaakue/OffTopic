package com.isaacgeraldo.offtopic.voiceplatform

import android.content.Context
import android.media.AudioManager
import com.isaacgeraldo.offtopic.voiceplatform.audio.AndroidAudioManagerFacade
import com.isaacgeraldo.offtopic.voiceplatform.audio.AudioRouterFactory
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
import kotlinx.coroutines.Dispatchers

/** Flutter entry point: wires the Pigeon channels to the Android implementation. */
class VoicePlatformPlugin internal constructor(
    private val keepScreenOn: ActivityKeepScreenOnController,
    private val coreFactory: () -> VoiceCoreBridge,
) : FlutterPlugin,
    ActivityAware {
    /** Used by the Flutter plugin registrant. */
    constructor() : this(ActivityKeepScreenOnController(), ::NativeVoiceCore)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val sdkLevel = SdkLevel.current()
        val audioManager = binding.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val core by lazy(coreFactory)
        val room =
            RoomController(
                core = { core },
                router = AudioRouterFactory.create(sdkLevel, AndroidAudioManagerFacade(audioManager)),
            )
        val api =
            VoicePlatformApiImpl(
                sdkLevel = sdkLevel,
                deviceInfo = AndroidDeviceInfoProvider(),
                keepScreenOn = keepScreenOn,
                room = room,
                roomDispatcher = Dispatchers.IO,
            )
        VoicePlatformHostApi.setUp(binding.binaryMessenger, api)
        WatchPlatformStateStreamHandler.register(binding.binaryMessenger, PlatformStateStreamHandler())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        VoicePlatformHostApi.setUp(binding.binaryMessenger, null)
        WatchPlatformStateEventChannel(binding.binaryMessenger).setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = keepScreenOn.attach(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = keepScreenOn.detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        keepScreenOn.attach(binding.activity)

    override fun onDetachedFromActivity() = keepScreenOn.detach()
}
