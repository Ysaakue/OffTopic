// Scripted voice processing for tests that are not about the DSP itself: a
// processor that records what it saw and a detector whose verdict the test
// sets. Thread-safe where the engine's media thread reads them.

#ifndef VOICE_CORE_TESTS_FAKES_FAKE_VOICE_PROCESSING_H_
#define VOICE_CORE_TESTS_FAKES_FAKE_VOICE_PROCESSING_H_

#include <atomic>
#include <cstdint>
#include <memory>

#include "dsp/voice_processing_factory.h"

namespace voice_core::testing {

/// Adds `offset` to every captured sample so a test can tell processed audio apart.
class RecordingAudioProcessor final : public IAudioProcessor {
 public:
  explicit RecordingAudioProcessor(int16_t offset = 0) noexcept : offset_(offset) {}

  void processCapture(int16_t* frame) noexcept override {
    frame[0] = static_cast<int16_t>(frame[0] + offset_);
    ++captured;
  }
  void analyzeRender(const int16_t* frame) noexcept override {
    lastRenderSample = frame[0];
    ++rendered;
  }

  std::atomic<int> captured{0};
  std::atomic<int> rendered{0};
  std::atomic<int16_t> lastRenderSample{0};

 private:
  const int16_t offset_;
};

class ScriptedVoiceDetector final : public IVoiceDetector {
 public:
  [[nodiscard]] bool isVoice(const int16_t* /*frame*/) noexcept override {
    ++calls;
    return voice.load();
  }
  void setSensitivity(VadSensitivity value) noexcept override { sensitivity = value; }

  std::atomic<bool> voice{true};
  std::atomic<int> calls{0};
  std::atomic<VadSensitivity> sensitivity{VadSensitivity::kMedium};
};

/// Hands out a passthrough-like recording processor and a scripted detector,
/// or fails with `failWith`.
class FakeVoiceProcessingFactory final : public IVoiceProcessingFactory {
 public:
  Expected<VoiceProcessing> create(const CoreConfig& config) override {
    lastConfig = config;
    if (failWith != Status::kOk) {
      return failWith;
    }
    auto detector = std::make_unique<ScriptedVoiceDetector>();
    detector->voice = voice.load();
    detector->sensitivity = config.vadSensitivity;
    lastDetector = detector.get();
    auto processor = std::make_unique<RecordingAudioProcessor>();
    lastProcessor = processor.get();
    return VoiceProcessing{std::move(processor), std::move(detector)};
  }

  Status failWith = Status::kOk;
  std::atomic<bool> voice{true};  // the verdict of the next detector
  CoreConfig lastConfig;
  ScriptedVoiceDetector* lastDetector = nullptr;    // valid while the engine runs
  RecordingAudioProcessor* lastProcessor = nullptr;  // valid while the engine runs
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_FAKE_VOICE_PROCESSING_H_
