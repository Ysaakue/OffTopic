// The parts of MiniaudioDevice that do not need hardware: the device
// configuration, the data callback trampoline and the lifecycle without start.

#include "audio/miniaudio_device.h"

#include <gtest/gtest.h>

#include <memory>
#include <vector>

#include "audio/miniaudio_config.h"

namespace voice_core {
namespace {

class RecordingCallback final : public IAudioCallback {
 public:
  void onAudio(const int16_t* input, int16_t* output, std::size_t frames) noexcept override {
    lastInput = input;
    lastOutput = output;
    lastFrames = frames;
  }
  const int16_t* lastInput = nullptr;
  int16_t* lastOutput = nullptr;
  std::size_t lastFrames = 0;
};

TEST(MiniaudioConfigTest, IsFullDuplexMonoS16AtTheCoreRate) {
  RecordingCallback callback;
  const ma_device_config config = makeDeviceConfig(AudioDeviceParams{16000, 160}, &callback);

  EXPECT_EQ(config.deviceType, ma_device_type_duplex);
  EXPECT_EQ(config.sampleRate, 16000U);
  EXPECT_EQ(config.periodSizeInFrames, 160U);
  // Low latency would open MMAP streams, which skip the platform echo canceller.
  EXPECT_EQ(config.performanceProfile, ma_performance_profile_conservative);
  EXPECT_EQ(config.capture.format, ma_format_s16);
  EXPECT_EQ(config.capture.channels, 1U);
  EXPECT_EQ(config.playback.format, ma_format_s16);
  EXPECT_EQ(config.playback.channels, 1U);
  EXPECT_EQ(config.pUserData, &callback);
  EXPECT_EQ(config.dataCallback, &miniaudioDataCallback);
}

TEST(MiniaudioConfigTest, TagsTheAndroidStreamsAsVoiceCommunication) {
  const ma_device_config config = makeDeviceConfig(AudioDeviceParams{16000, 160}, nullptr);

  EXPECT_EQ(config.aaudio.usage, ma_aaudio_usage_voice_communication);
  EXPECT_EQ(config.aaudio.contentType, ma_aaudio_content_type_speech);
  EXPECT_EQ(config.aaudio.inputPreset, ma_aaudio_input_preset_voice_communication);
  EXPECT_EQ(config.aaudio.allowedCapturePolicy, ma_aaudio_allow_capture_by_none);
  EXPECT_EQ(config.opensl.streamType, ma_opensl_stream_type_voice);
  EXPECT_EQ(config.opensl.recordingPreset, ma_opensl_recording_preset_voice_communication);
}

TEST(MiniaudioDataCallbackTest, ForwardsToTheCoreCallback) {
  RecordingCallback callback;
  auto device = std::make_unique<ma_device>();
  device->pUserData = &callback;
  std::vector<int16_t> input(4);
  std::vector<int16_t> output(4);

  miniaudioDataCallback(device.get(), output.data(), input.data(), 4);

  EXPECT_EQ(callback.lastInput, input.data());
  EXPECT_EQ(callback.lastOutput, output.data());
  EXPECT_EQ(callback.lastFrames, 4U);
}

TEST(MiniaudioDeviceTest, StopsSafelyWithoutStarting) {
  MiniaudioDevice device(AudioDeviceParams{16000, 160});

  device.stop();
  device.stop();
}

TEST(MiniaudioDeviceFactoryTest, CreatesADevice) {
  MiniaudioDeviceFactory factory;

  EXPECT_NE(factory.create(AudioDeviceParams{16000, 160}), nullptr);
}

}  // namespace
}  // namespace voice_core
