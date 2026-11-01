package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.VoicePlatformHostApi
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateEventChannel
import com.isaacgeraldo.offtopic.voiceplatform.generated.WatchPlatformStateStreamHandler
import com.isaacgeraldo.offtopic.voiceplatform.system.ActivityKeepScreenOnController
import com.isaacgeraldo.offtopic.voiceplatform.system.AndroidDeviceInfoProvider
import com.isaacgeraldo.offtopic.voiceplatform.system.SdkLevel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** Flutter entry point: wires the Pigeon channels to the Android implementation. */
class VoicePlatformPlugin internal constructor(
    private val keepScreenOn: ActivityKeepScreenOnController,
) : FlutterPlugin,
    ActivityAware {
    /** Used by the Flutter plugin registrant. */
    constructor() : this(ActivityKeepScreenOnController())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val api =
            VoicePlatformApiImpl(
                sdkLevel = SdkLevel.current(),
                deviceInfo = AndroidDeviceInfoProvider(),
                keepScreenOn = keepScreenOn,
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
