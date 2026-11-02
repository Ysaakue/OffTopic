// IAudioDevice on top of miniaudio (AAudio/OpenSL ES on Android, Core Audio on
// iOS, PulseAudio/ALSA on Linux).

#ifndef VOICE_CORE_SRC_AUDIO_MINIAUDIO_DEVICE_H_
#define VOICE_CORE_SRC_AUDIO_MINIAUDIO_DEVICE_H_

#include <memory>

#include "audio/audio_device.h"

namespace voice_core {

class MiniaudioDevice final : public IAudioDevice {
 public:
  explicit MiniaudioDevice(const AudioDeviceParams& params);
  ~MiniaudioDevice() override;
  MiniaudioDevice(const MiniaudioDevice&) = delete;
  MiniaudioDevice& operator=(const MiniaudioDevice&) = delete;
  MiniaudioDevice(MiniaudioDevice&&) = delete;
  MiniaudioDevice& operator=(MiniaudioDevice&&) = delete;

  Status start(IAudioCallback& callback) override;
  void stop() noexcept override;

 private:
  struct State;  // owns the ma_device (kept out of this header)
  const AudioDeviceParams params_;
  std::unique_ptr<State> state_;
};

class MiniaudioDeviceFactory final : public IAudioDeviceFactory {
 public:
  std::unique_ptr<IAudioDevice> create(const AudioDeviceParams& params) override {
    return std::make_unique<MiniaudioDevice>(params);
  }
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_AUDIO_MINIAUDIO_DEVICE_H_
