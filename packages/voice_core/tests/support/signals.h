// Deterministic test signals for the DSP tests (seeded noise, tones) and
// their energy.

#ifndef VOICE_CORE_TESTS_SUPPORT_SIGNALS_H_
#define VOICE_CORE_TESTS_SUPPORT_SIGNALS_H_

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <random>
#include <vector>

namespace voice_core::testing {

constexpr double kPi = 3.14159265358979323846;
constexpr int kTestRateHz = 16000;

/// Gaussian white noise, clipped to 16 bits.
class NoiseSource {
 public:
  NoiseSource(double stddev, uint32_t seed) : random_(seed), noise_(0.0, stddev) {}

  std::vector<int16_t> next(std::size_t samples) {
    std::vector<int16_t> out(samples);
    for (int16_t& sample : out) {
      const double value = std::clamp(noise_(random_), -32768.0, 32767.0);
      sample = static_cast<int16_t>(std::lround(value));
    }
    return out;
  }

 private:
  std::mt19937 random_;
  std::normal_distribution<double> noise_;
};

/// A voiced, speech-like tone: fundamental `f0` with its third harmonic.
/// `start` is the index of the first sample, so consecutive frames join up.
inline std::vector<int16_t> harmonicTone(std::size_t samples, std::size_t start, double f0,
                                         double amplitude) {
  std::vector<int16_t> out(samples);
  for (std::size_t i = 0; i < samples; ++i) {
    const double t = static_cast<double>(start + i) / kTestRateHz;
    const double value =
        amplitude * (std::sin(2.0 * kPi * f0 * t) + 0.5 * std::sin(2.0 * kPi * 3.0 * f0 * t));
    out[i] = static_cast<int16_t>(std::lround(value));
  }
  return out;
}

inline double energy(const std::vector<int16_t>& samples) {
  double sum = 0.0;
  for (const int16_t sample : samples) {
    sum += static_cast<double>(sample) * static_cast<double>(sample);
  }
  return sum;
}

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_SUPPORT_SIGNALS_H_
