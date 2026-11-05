package com.isaacgeraldo.offtopic.voiceplatform.call

/**
 * Tries [primary] (the system call) and, if the system refuses it, uses
 * [fallback] (direct routing), so the room starts either way.
 */
internal class FallbackCallAudio(
    private val primary: CallAudio,
    private val fallback: CallAudio,
) : CallAudio {
    private var active: CallAudio? = null

    @Synchronized
    override fun start(events: CallEvents): CallStart {
        val (used, start) =
            try {
                primary to primary.start(events)
            } catch (refused: Exception) {
                fallback to fallback.start(events)
            }
        active = used
        return start
    }

    @Synchronized
    override fun stop() {
        active?.stop()
        active = null
    }
}
