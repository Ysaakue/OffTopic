package com.isaacgeraldo.offtopic.voiceplatform.call

import android.content.Context
import android.net.Uri
import android.telecom.DisconnectCause
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlResult
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallEndpointCompat
import androidx.core.telecom.CallsManager
import com.isaacgeraldo.offtopic.voiceplatform.CoverageExcluded
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * [CallPlatform] over Jetpack Core-Telecom: the room becomes a self-managed
 * call, so Bluetooth headsets see a real call and the system routes it.
 *
 * Excluded from coverage: a device-only shell (closed exclusion list in
 * CLAUDE.md). Telecom's call APIs do not run under Robolectric; the logic
 * that drives this class (TelecomCallAudio) is tested with fakes.
 */
@CoverageExcluded
internal class TelecomCallPlatform(
    private val context: Context,
) : CallPlatform {
    private val callsManager by lazy {
        CallsManager(context).also { it.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE) }
    }

    override suspend fun addCall(
        displayName: String,
        callbacks: CallSessionCallbacks,
        onCall: (CallSession) -> Unit,
    ) {
        callsManager.addCall(
            CallAttributesCompat(
                displayName,
                Uri.parse(ROOM_ADDRESS),
                CallAttributesCompat.DIRECTION_OUTGOING,
                CallAttributesCompat.CALL_TYPE_AUDIO_CALL,
                CallAttributesCompat.SUPPORTS_SET_INACTIVE,
            ),
            onAnswer = {}, // outgoing: Telecom never asks to answer it
            onDisconnect = { callbacks.onDisconnect() },
            onSetActive = { callbacks.onSetActive() },
            onSetInactive = { callbacks.onSetInactive() },
        ) {
            onCall(TelecomCallSession(this))
        }
    }

    private class TelecomCallSession(
        private val control: CallControlScope,
    ) : CallSession {
        override val scope: CoroutineScope = control

        override val currentEndpoint: Flow<CallEndpoint> = control.currentCallEndpoint.map { it.toEndpoint() }

        override val availableEndpoints: Flow<List<CallEndpoint>> =
            control.availableEndpoints.map { endpoints -> endpoints.map { it.toEndpoint() } }

        override suspend fun setActive(): Boolean = control.setActive() is CallControlResult.Success

        override suspend fun requestEndpoint(endpoint: CallEndpoint): Boolean =
            (endpoint.handle as? CallEndpointCompat)?.let {
                control.requestEndpointChange(it) is CallControlResult.Success
            } ?: false

        override suspend fun disconnect() {
            control.disconnect(DisconnectCause(DisconnectCause.LOCAL))
        }
    }

    private companion object {
        const val ROOM_ADDRESS = "offtopic:room"

        fun CallEndpointCompat.toEndpoint() =
            CallEndpoint(
                type =
                    when (type) {
                        CallEndpointCompat.TYPE_BLUETOOTH -> EndpointType.BLUETOOTH
                        CallEndpointCompat.TYPE_WIRED_HEADSET -> EndpointType.WIRED_HEADSET
                        CallEndpointCompat.TYPE_SPEAKER -> EndpointType.SPEAKER
                        CallEndpointCompat.TYPE_EARPIECE -> EndpointType.EARPIECE
                        else -> EndpointType.OTHER
                    },
                handle = this,
            )
    }
}
