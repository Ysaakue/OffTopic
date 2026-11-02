// Full-duplex audio device abstraction. MiniaudioDevice is the real one;
// tests drive a FakeAudioDevice by hand.

#ifndef VOICE_CORE_SRC_AUDIO_AUDIO_DEVICE_H_
#define VOICE_CORE_SRC_AUDIO_AUDIO_DEVICE_H_

#include <cstddef>
#include <cstdint>
#include <memory>

#include "common/expected.h"

namespace voice_core {

/// Runs on the real-time audio thread: must not allocate, lock, do I/O or log.
class IAudioCallback {
 public:
  virtual ~IAudioCallback() = default;
  IAudioCallback() = default;
  IAudioCallback(const IAudioCallback&) = delete;
  IAudioCallback& operator=(const IAudioCallback&) = delete;
  IAudioCallback(IAudioCallback&&) = delete;
  IAudioCallback& operator=(IAudioCallback&&) = delete;

  /// `input` holds `frames` captured samples (mono, s16); fill `output` with
  /// `frames` samples to play.
  virtual void onAudio(const int16_t* input, int16_t* output, std::size_t frames) noexcept = 0;
};

struct AudioDeviceParams {
  int sampleRateHz = 0;
  int periodFrames = 0;
};

class IAudioDevice {
 public:
  virtual ~IAudioDevice() = default;
  IAudioDevice() = default;
  IAudioDevice(const IAudioDevice&) = delete;
  IAudioDevice& operator=(const IAudioDevice&) = delete;
  IAudioDevice(IAudioDevice&&) = delete;
  IAudioDevice& operator=(IAudioDevice&&) = delete;

  /// Opens the device and starts calling `callback`. kAudioDevice on failure.
  virtual Status start(IAudioCallback& callback) = 0;

  /// Stops the callbacks and closes the device. Safe to call twice.
  virtual void stop() noexcept = 0;
};

class IAudioDeviceFactory {
 public:
  virtual ~IAudioDeviceFactory() = default;
  IAudioDeviceFactory() = default;
  IAudioDeviceFactory(const IAudioDeviceFactory&) = delete;
  IAudioDeviceFactory& operator=(const IAudioDeviceFactory&) = delete;
  IAudioDeviceFactory(IAudioDeviceFactory&&) = delete;
  IAudioDeviceFactory& operator=(IAudioDeviceFactory&&) = delete;

  virtual std::unique_ptr<IAudioDevice> create(const AudioDeviceParams& params) = 0;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_AUDIO_AUDIO_DEVICE_H_
