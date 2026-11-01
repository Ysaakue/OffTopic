package com.isaacgeraldo.offtopic.voiceplatform

import com.isaacgeraldo.offtopic.voiceplatform.generated.FlutterError

/** Error codes shared with Dart (see VoicePlatformErrorCode in voice_platform). */
object PlatformErrorCodes {
    const val NOT_IMPLEMENTED = "not_implemented"
}

internal object PlatformErrors {
    /** A host method whose implementation is scheduled for a later phase. */
    fun notImplemented(method: String): FlutterError =
        FlutterError(
            code = PlatformErrorCodes.NOT_IMPLEMENTED,
            message = "$method is not implemented yet on Android.",
        )
}
