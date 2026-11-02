// The miniaudio device configuration used by MiniaudioDevice, separated so the
// settings (voice usage, mono s16, low latency) are unit tested on desktop.

#ifndef VOICE_CORE_SRC_AUDIO_MINIAUDIO_CONFIG_H_
#define VOICE_CORE_SRC_AUDIO_MINIAUDIO_CONFIG_H_

#include <miniaudio.h>

#include "audio/audio_device.h"

namespace voice_core {

/// miniaudio data callback: forwards to the IAudioCallback in pUserData.
void miniaudioDataCallback(ma_device* device, void* output, const void* input,
                           ma_uint32 frames);

/// Full-duplex, 16-bit mono, on the normal (non-MMAP) path so the platform
/// voice processing applies. On Android the streams are tagged as
/// voice communication (AAudio usage, content type and input preset; OpenSL
/// stream type and recording preset) so that the system routes them like a
/// call (headset or intercom) and applies its voice processing.
[[nodiscard]] ma_device_config makeDeviceConfig(const AudioDeviceParams& params,
                                                IAudioCallback* callback) noexcept;

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_AUDIO_MINIAUDIO_CONFIG_H_
