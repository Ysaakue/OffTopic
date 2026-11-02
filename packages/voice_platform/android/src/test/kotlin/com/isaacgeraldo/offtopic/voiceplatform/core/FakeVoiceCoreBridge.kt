package com.isaacgeraldo.offtopic.voiceplatform.core

/** Records calls into a shared log, so tests can check the order across collaborators. */
internal class FakeVoiceCoreBridge(
    private val log: MutableList<String> = mutableListOf(),
) : VoiceCoreBridge {
    var initResult = CoreResult.OK
    var startResult = CoreResult.OK
    var lastConfig: CoreSessionConfig? = null
    val mutes = mutableListOf<Boolean>()

    override fun init(config: CoreSessionConfig): Int {
        log += "core.init"
        lastConfig = config
        return initResult
    }

    override fun start(): Int {
        log += "core.start"
        return startResult
    }

    override fun stop() {
        log += "core.stop"
    }

    override fun setMute(muted: Boolean) {
        log += "core.mute"
        mutes += muted
    }
}
