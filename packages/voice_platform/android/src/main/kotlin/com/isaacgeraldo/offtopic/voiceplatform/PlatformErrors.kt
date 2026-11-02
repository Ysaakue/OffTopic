package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.core.CoreResult
import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError

/** Error codes shared with Dart (see VoicePlatformErrorCode in voice_platform). */
object PlatformErrorCodes {
    const val NOT_IMPLEMENTED = "not_implemented"
    const val ROOM_ALREADY_ACTIVE = "room_already_active"
    const val NO_ACTIVE_ROOM = "no_active_room"
    const val INVALID_CONFIG = "invalid_config"
    const val AUDIO_DEVICE_ERROR = "audio_device_error"
    const val NETWORK_ERROR = "network_error"
    const val CORE_ERROR = "core_error"
}

internal object PlatformErrors {
    /** A host method whose implementation is scheduled for a later phase. */
    fun notImplemented(method: String): FlutterError =
        FlutterError(
            code = PlatformErrorCodes.NOT_IMPLEMENTED,
            message = "$method is not implemented yet on Android.",
        )

    fun roomAlreadyActive(): FlutterError =
        FlutterError(PlatformErrorCodes.ROOM_ALREADY_ACTIVE, "A room is already running.")

    fun noActiveRoom(): FlutterError = FlutterError(PlatformErrorCodes.NO_ACTIVE_ROOM, "No room is running.")

    /** A failed vc_* call; `details` carries the vc_result code. */
    fun core(
        operation: String,
        result: Int,
    ): FlutterError {
        val code =
            when (result) {
                CoreResult.INVALID_ARGUMENT -> PlatformErrorCodes.INVALID_CONFIG
                CoreResult.INVALID_STATE -> PlatformErrorCodes.ROOM_ALREADY_ACTIVE
                CoreResult.AUDIO_DEVICE -> PlatformErrorCodes.AUDIO_DEVICE_ERROR
                CoreResult.NETWORK -> PlatformErrorCodes.NETWORK_ERROR
                else -> PlatformErrorCodes.CORE_ERROR
            }
        return FlutterError(code, "$operation failed with voice core error $result.", result.toLong())
    }
}
