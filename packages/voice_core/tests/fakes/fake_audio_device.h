// IAudioDevice whose callback the test drives by hand (no hardware, no thread).

#ifndef VOICE_CORE_TESTS_FAKES_FAKE_AUDIO_DEVICE_H_
#define VOICE_CORE_TESTS_FAKES_FAKE_AUDIO_DEVICE_H_

#include <atomic>
#include <cstdint>
#include <deque>
#include <memory>
#include <vector>

#include "audio/audio_device.h"

namespace voice_core::testing {

class FakeAudioDevice final : public IAudioDevice {
 public:
  /// `stopCounter` outlives the device (the engine destroys it after stop()).
  FakeAudioDevice(Status startStatus, std::atomic<int>& stopCounter)
      : startStatus_(startStatus), stopCounter_(stopCounter) {}

  Status start(IAudioCallback& callback) override {
    ++starts_;
    if (startStatus_ == Status::kOk) {
      callback_.store(&callback);
    }
    return startStatus_;
  }

  void stop() noexcept override {
    ++stopCounter_;
    callback_.store(nullptr);
  }

  /// Runs one callback: `input` is captured, the played samples are returned.
  std::vector<int16_t> pump(const std::vector<int16_t>& input) {
    std::vector<int16_t> output(input.size(), -1);
    IAudioCallback* callback = callback_.load();
    if (callback != nullptr) {
      callback->onAudio(input.data(), output.data(), input.size());
    }
    return output;
  }

  [[nodiscard]] bool started() const { return callback_.load() != nullptr; }
  [[nodiscard]] int starts() const { return starts_; }

 private:
  const Status startStatus_;
  std::atomic<int>& stopCounter_;
  std::atomic<IAudioCallback*> callback_{nullptr};
  int starts_ = 0;
};

class FakeAudioDeviceFactory final : public IAudioDeviceFactory {
 public:
  std::unique_ptr<IAudioDevice> create(const AudioDeviceParams& params) override {
    lastParams = params;
    Status status = startStatus;
    if (!startStatuses.empty()) {
      status = startStatuses.front();
      startStatuses.pop_front();
    }
    auto device = std::make_unique<FakeAudioDevice>(status, stops);
    last = device.get();
    ++created;
    return device;
  }

  Status startStatus = Status::kOk;
  std::deque<Status> startStatuses;  // one per created device, then startStatus
  AudioDeviceParams lastParams;
  FakeAudioDevice* last = nullptr;  // valid only while the engine runs
  int created = 0;
  std::atomic<int> stops{0};  // stop() calls over every created device
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_FAKE_AUDIO_DEVICE_H_
