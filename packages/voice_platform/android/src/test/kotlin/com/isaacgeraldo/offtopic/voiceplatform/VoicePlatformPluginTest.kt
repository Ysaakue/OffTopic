package com.isaacgeraldo.offtopic.voiceplatform

import android.app.Activity
import android.view.WindowManager
import com.isaacgeraldo.offtopic.voiceplatform.system.ActivityKeepScreenOnController
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37])
class VoicePlatformPluginTest {
    private val messenger = mockk<BinaryMessenger>(relaxed = true)
    private val engineBinding =
        mockk<FlutterPlugin.FlutterPluginBinding> {
            every { binaryMessenger } returns messenger
        }
    private val keepScreenOn = ActivityKeepScreenOnController()
    private val plugin = VoicePlatformPlugin(keepScreenOn)

    @Test
    fun `attaching to the engine registers the host api and the state stream`() {
        plugin.onAttachedToEngine(engineBinding)

        verify { messenger.setMessageHandler(HOST_API_CHANNEL, isNull(inverse = true)) }
        verify { messenger.setMessageHandler(STATE_STREAM_CHANNEL, isNull(inverse = true)) }
    }

    @Test
    fun `detaching from the engine removes every handler`() {
        plugin.onAttachedToEngine(engineBinding)

        plugin.onDetachedFromEngine(engineBinding)

        verify { messenger.setMessageHandler(HOST_API_CHANNEL, null) }
        verify { messenger.setMessageHandler(STATE_STREAM_CHANNEL, null) }
    }

    @Test
    fun `reattaching after a config change moves the controller to the new activity`() {
        val first = Robolectric.buildActivity(Activity::class.java).setup().get()
        val second = Robolectric.buildActivity(Activity::class.java).setup().get()
        plugin.onAttachedToActivity(activityBinding(first))
        plugin.onDetachedFromActivityForConfigChanges()
        plugin.onReattachedToActivityForConfigChanges(activityBinding(second))

        keepScreenOn.setKeepScreenOn(true)

        assertTrue(second.keepsScreenOn())
        assertFalse(first.keepsScreenOn())
    }

    @Test
    fun `detaching from the activity stops applying the preference`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        plugin.onAttachedToActivity(activityBinding(activity))

        plugin.onDetachedFromActivity()
        keepScreenOn.setKeepScreenOn(true)

        assertFalse(activity.keepsScreenOn())
    }

    @Test
    fun `the default constructor builds a working plugin`() {
        VoicePlatformPlugin().onAttachedToEngine(engineBinding)

        verify { messenger.setMessageHandler(HOST_API_CHANNEL, isNull(inverse = true)) }
    }

    private fun activityBinding(activity: Activity) =
        mockk<ActivityPluginBinding> {
            every { this@mockk.activity } returns activity
        }

    private fun Activity.keepsScreenOn(): Boolean =
        window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0

    private companion object {
        const val HOST_API_CHANNEL = "dev.flutter.pigeon.voice_platform.VoicePlatformHostApi.getPlatformInfo"
        const val STATE_STREAM_CHANNEL = "dev.flutter.pigeon.voice_platform.VoicePlatformEventApi.watchPlatformState"
    }
}
