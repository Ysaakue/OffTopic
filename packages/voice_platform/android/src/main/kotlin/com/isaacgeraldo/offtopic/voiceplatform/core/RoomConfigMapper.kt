package com.isaacgeraldo.offtopic.voiceplatform.core

import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomConfigMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.RoomRoleMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.TalkModeMessage
import com.isaacgeraldo.offtopic.voiceplatform.generated.VadSensitivityMessage

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
        talkMode =
            when (talkMode) {
                TalkModeMessage.VOICE -> CoreTalkMode.VOICE
                TalkModeMessage.PUSH_TO_TALK -> CoreTalkMode.PUSH_TO_TALK
            },
        vadSensitivity =
            when (vadSensitivity) {
                VadSensitivityMessage.LOW -> CoreVadSensitivity.LOW
                VadSensitivityMessage.MEDIUM -> CoreVadSensitivity.MEDIUM
                VadSensitivityMessage.HIGH -> CoreVadSensitivity.HIGH
            },
    )
