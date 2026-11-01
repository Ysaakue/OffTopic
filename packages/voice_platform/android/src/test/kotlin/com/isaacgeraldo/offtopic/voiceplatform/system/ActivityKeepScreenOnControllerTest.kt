package com.isaacgeraldo.offtopic.voiceplatform.system

import android.app.Activity
import android.view.WindowManager
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37])
class ActivityKeepScreenOnControllerTest {
    private lateinit var activity: Activity
    private lateinit var controller: ActivityKeepScreenOnController

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        controller = ActivityKeepScreenOnController()
    }

    @Test
    fun `enabling adds the keep screen on flag`() {
        controller.attach(activity)

        controller.setKeepScreenOn(true)

        assertTrue(activity.keepsScreenOn())
    }

    @Test
    fun `disabling clears the keep screen on flag`() {
        controller.attach(activity)
        controller.setKeepScreenOn(true)

        controller.setKeepScreenOn(false)

        assertFalse(activity.keepsScreenOn())
    }

    @Test
    fun `preference set without an activity is applied on attach`() {
        controller.setKeepScreenOn(true)

        controller.attach(activity)

        assertTrue(activity.keepsScreenOn())
    }

    @Test
    fun `changes after detach do not touch the old activity`() {
        controller.attach(activity)
        controller.detach()

        controller.setKeepScreenOn(true)

        assertFalse(activity.keepsScreenOn())
    }

    private fun Activity.keepsScreenOn(): Boolean =
        window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0
}
