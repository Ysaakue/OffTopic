#include "audio/miniaudio_device.h"

#include "audio/miniaudio_config.h"

namespace voice_core {

void miniaudioDataCallback(ma_device* device, void* output, const void* input,
                           ma_uint32 frames) {
  auto* callback = static_cast<IAudioCallback*>(device->pUserData);
  callback->onAudio(static_cast<const int16_t*>(input), static_cast<int16_t*>(output), frames);
}

ma_device_config makeDeviceConfig(const AudioDeviceParams& params,
                                  IAudioCallback* callback) noexcept {
  ma_device_config config = ma_device_config_init(ma_device_type_duplex);
  config.sampleRate = static_cast<ma_uint32>(params.sampleRateHz);
  config.periodSizeInFrames = static_cast<ma_uint32>(params.periodFrames);
  // Not low_latency: on AAudio that opens MMAP streams, where the platform
  // voice processing (echo canceller, noise suppressor) is not applied and a
  // route change disconnects the stream (seen on a Galaxy A54, Android 16).
  // Calls take the normal path, as WebRTC does.
  config.performanceProfile = ma_performance_profile_conservative;
  config.capture.format = ma_format_s16;
  config.capture.channels = 1;
  config.playback.format = ma_format_s16;
  config.playback.channels = 1;
  config.dataCallback = miniaudioDataCallback;
  config.pUserData = callback;
  config.aaudio.usage = ma_aaudio_usage_voice_communication;
  config.aaudio.contentType = ma_aaudio_content_type_speech;
  config.aaudio.inputPreset = ma_aaudio_input_preset_voice_communication;
  config.aaudio.allowedCapturePolicy = ma_aaudio_allow_capture_by_none;
  config.opensl.streamType = ma_opensl_stream_type_voice;
  config.opensl.recordingPreset = ma_opensl_recording_preset_voice_communication;
  return config;
}

struct MiniaudioDevice::State {
  ma_device device{};
  bool open = false;
};

MiniaudioDevice::MiniaudioDevice(const AudioDeviceParams& params)
    : params_(params), state_(std::make_unique<State>()) {}

MiniaudioDevice::~MiniaudioDevice() { stop(); }

// GCOVR_EXCL_START: opens the real audio hardware. Device-only shell in the
// closed exclusion list (CLAUDE.md); exercised on the phones.
Status MiniaudioDevice::start(IAudioCallback& callback) {
  if (state_->open) {
    return Status::kInvalidState;
  }
  const ma_device_config config = makeDeviceConfig(params_, &callback);
  if (ma_device_init(nullptr, &config, &state_->device) != MA_SUCCESS) {
    return Status::kAudioDevice;
  }
  state_->open = true;
  if (ma_device_start(&state_->device) != MA_SUCCESS) {
    stop();
    return Status::kAudioDevice;
  }
  return Status::kOk;
}
// GCOVR_EXCL_STOP

void MiniaudioDevice::stop() noexcept {
  if (state_->open) {   // GCOVR_EXCL_BR_LINE: only true after start(), which needs hardware
    ma_device_uninit(&state_->device);  // GCOVR_EXCL_LINE: see above
    state_->open = false;               // GCOVR_EXCL_LINE: see above
  }
}

}  // namespace voice_core
