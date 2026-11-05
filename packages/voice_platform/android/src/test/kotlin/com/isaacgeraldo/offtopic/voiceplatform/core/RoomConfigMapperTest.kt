package com.isaacgeraldo.offtopic.voiceplatform.core

import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.TalkModeMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.VadSensitivityMessage
import org.junit.Test
import kotlin.test.assertEquals

class RoomConfigMapperTest {
    @Test
    fun `a client keeps the host address and every field`() {
        val config = message().toCoreConfig()

        assertEquals(
            CoreSessionConfig(
                role = CoreRole.CLIENT,
                hostIp = "192.168.43.1",
                controlPort = 47800,
                audioPort = 47801,
                displayName = "Ana",
                bitrateBps = 24000,
                echoMode = false,
                talkMode = CoreTalkMode.VOICE,
                vadSensitivity = CoreVadSensitivity.MEDIUM,
            ),
            config,
        )
    }

    @Test
    fun `a host has no host address and may echo`() {
        val config =
            message()
                .copy(
                    role = RoomRoleMessage.HOST,
                    hostIp = null,
                    displayName = "Bia",
                    controlPort = 50000,
                    audioPort = 50001,
                    bitrateBps = 32000,
                    echoMode = true,
                ).toCoreConfig()

        assertEquals(CoreRole.HOST, config.role)
        assertEquals(null, config.hostIp)
        assertEquals(true, config.echoMode)
        assertEquals(50001, config.audioPort)
    }

    @Test
    fun `maps every talk mode`() {
        assertEquals(CoreTalkMode.VOICE, message(talkMode = TalkModeMessage.VOICE).toCoreConfig().talkMode)
        assertEquals(
            CoreTalkMode.PUSH_TO_TALK,
            message(talkMode = TalkModeMessage.PUSH_TO_TALK).toCoreConfig().talkMode,
        )
    }

    @Test
    fun `maps every voice detector sensitivity`() {
        mapOf(
            VadSensitivityMessage.LOW to CoreVadSensitivity.LOW,
            VadSensitivityMessage.MEDIUM to CoreVadSensitivity.MEDIUM,
            VadSensitivityMessage.HIGH to CoreVadSensitivity.HIGH,
        ).forEach { (sensitivity, core) ->
            assertEquals(core, message(vadSensitivity = sensitivity).toCoreConfig().vadSensitivity)
        }
    }

    private fun message(
        talkMode: TalkModeMessage = TalkModeMessage.VOICE,
        vadSensitivity: VadSensitivityMessage = VadSensitivityMessage.MEDIUM,
    ) = RoomConfigMessage(
        role = RoomRoleMessage.CLIENT,
        hostIp = "192.168.43.1",
        displayName = "Ana",
        controlPort = 47800,
        audioPort = 47801,
        bitrateBps = 24000,
        echoMode = false,
        talkMode = talkMode,
        vadSensitivity = vadSensitivity,
    )
}
