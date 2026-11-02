package com.isaacgeraldo.offtopic.voiceplatform.core

import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage

/** Converts the Pigeon room configuration into what vc_init receives. */
internal fun RoomConfigMessage.toCoreConfig(): CoreSessionConfig =
    CoreSessionConfig(
        role =
            when (role) {
                RoomRoleMessage.HOST -> CoreRole.HOST
                RoomRoleMessage.CLIENT -> CoreRole.CLIENT
            },
        hostIp = hostIp,
        controlPort = controlPort.toInt(),
        audioPort = audioPort.toInt(),
        displayName = displayName,
        bitrateBps = bitrateBps.toInt(),
        echoMode = echoMode,
    )
