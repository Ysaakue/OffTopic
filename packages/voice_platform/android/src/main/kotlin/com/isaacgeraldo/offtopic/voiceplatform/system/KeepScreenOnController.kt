package com.isaacgeraldo.offtopic.voiceplatform.system

import android.app.Activity
import android.view.WindowManager

/** Keeps the screen awake while the rider looks at the room screen. */
interface KeepScreenOnController {
    fun setKeepScreenOn(enabled: Boolean)
}

/**
 * Applies `FLAG_KEEP_SCREEN_ON` to the current activity window.
 *
 * The preference is remembered while no activity is attached and applied as
 * soon as one attaches, so the call never fails because of the UI lifecycle.
 */
class ActivityKeepScreenOnController : KeepScreenOnController {
    private var activity: Activity? = null
    private var enabled = false

    fun attach(activity: Activity) {
        this.activity = activity
        apply()
    }

    fun detach() {
        activity = null
    }

    override fun setKeepScreenOn(enabled: Boolean) {
        this.enabled = enabled
        apply()
    }

    private fun apply() {
        val current = activity ?: return
        val keepOn = enabled
        current.runOnUiThread {
            if (keepOn) {
                current.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                current.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }
}
