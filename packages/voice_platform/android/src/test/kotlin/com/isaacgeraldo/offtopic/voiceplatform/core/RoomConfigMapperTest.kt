package com.isaacgeraldo.offtopic.voiceplatform.core

import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import org.junit.Test
import kotlin.test.assertEquals

class RoomConfigMapperTest {
    @Test
    fun `a client keeps the host address and every field`() {
        val config =
            RoomConfigMessage(
                role = RoomRoleMessage.CLIENT,
                hostIp = "192.168.43.1",
                displayName = "Ana",
                controlPort = 47800,
                audioPort = 47801,
                bitrateBps = 24000,
                echoMode = false,
            ).toCoreConfig()

        assertEquals(
            CoreSessionConfig(
                role = CoreRole.CLIENT,
                hostIp = "192.168.43.1",
                controlPort = 47800,
                audioPort = 47801,
                displayName = "Ana",
                bitrateBps = 24000,
                echoMode = false,
            ),
            config,
        )
    }

    @Test
    fun `a host has no host address and may echo`() {
        val config =
            RoomConfigMessage(
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
}
