// The single configuration struct of the core. Every audio and network
// parameter lives here; components receive the values they need from it and
// never define their own tunables. Defaults follow docs/SPEC.md.

#ifndef VOICE_CORE_SRC_CONFIG_CORE_CONFIG_H_
#define VOICE_CORE_SRC_CONFIG_CORE_CONFIG_H_

#include <cstdint>
#include <string>

namespace voice_core {

enum class Role : uint8_t { kClient, kHost };

/// Strength of the noise suppressor (WebRTC NS levels), or off.
enum class NoiseSuppression : uint8_t { kOff, kLow, kModerate, kHigh, kVeryHigh };

/// Voice: the voice detector opens the microphone. Push to talk: only while held.
enum class TalkMode : uint8_t { kVoice, kPushToTalk };

/// How easily the voice detector opens: low needs clear speech, high also
/// opens on quiet speech (and more noise).
enum class VadSensitivity : uint8_t { kLow, kMedium, kHigh };

struct CoreConfig {
  // --- Session
  Role role = Role::kClient;
  std::string hostIp;       // client only; ignored on the host
  std::string displayName;  // 1..32 characters (sent in HELLO from phase 3)
  bool echoMode = false;    // host only: return every audio datagram to its sender

  // --- Ports (PROTOCOL.md)
  uint16_t controlPort = 47800;  // TCP
  uint16_t audioPort = 47801;    // UDP
  int audioDscp = 46;            // Expedited Forwarding: Wi-Fi WMM voice queue

  // --- Codec (Opus, protocol version 1)
  int sampleRateHz = 16000;
  int frameSamples = 320;  // 20 ms
  int bitrateBps = 24000;
  bool fecEnabled = true;
  int expectedLossPct = 10;
  bool dtxEnabled = true;
  int opusComplexity = 5;

  // --- Jitter buffer
  int jitterMinMs = 20;
  int jitterInitialMs = 40;
  int jitterMaxMs = 120;
  int jitterAdaptHoldMs = 500;     // depth must stay off target this long before a drop/insert
  int jitterWindowMs = 4000;       // memory of the delay estimator
  int concealmentMaxMs = 100;      // longest run of packet loss concealment before silence

  // --- Audio device and media loop
  int devicePeriodMs = 10;
  int playoutBufferMs = 20;  // decoded audio queued for the device
  int mediaLoopPeriodMs = 2;
  int networkPollMs = 20;

  // --- Liveness and statistics
  int keepaliveIntervalMs = 1000;
  int peerTimeoutMs = 5000;
  int statsIntervalMs = 1000;  // window of the loss percentage
  int controlPingIntervalMs = 1000;  // phase 3
  int controlTimeoutMs = 5000;       // phase 3
  int reconnectGraceMs = 30000;      // phase 4

  // --- Voice processing (microphone, before encoding)
  NoiseSuppression noiseSuppression = NoiseSuppression::kHigh;  // wind and engine noise
  bool automaticGain = true;      // adaptive digital gain (WebRTC AGC2)
  bool highPassFilter = true;     // removes rumble below about 80 Hz
  bool echoCancellation = false;  // software AEC; the call path already cancels echo
  TalkMode talkMode = TalkMode::kVoice;
  VadSensitivity vadSensitivity = VadSensitivity::kMedium;
  int vadTailMs = 300;  // the microphone stays open this long after speech stops

  // --- Room
  int maxParticipants = 8;  // phase 3

  [[nodiscard]] int frameMs() const noexcept { return frameSamples * kMsPerSecond / sampleRateHz; }
  [[nodiscard]] int msToSamples(int ms) const noexcept { return ms * sampleRateHz / kMsPerSecond; }

  static constexpr int kMsPerSecond = 1000;
};

/// The first invalid field found by validate(), or kNone.
enum class ConfigError : uint8_t {
  kNone,
  kHostIp,
  kDisplayName,
  kEchoModeOnClient,
  kControlPort,
  kAudioPort,
  kAudioDscp,
  kSampleRate,
  kFrameSamples,
  kBitrate,
  kExpectedLoss,
  kOpusComplexity,
  kJitterRange,
  kJitterAdaptation,
  kConcealment,
  kDeviceTiming,
  kKeepalive,
  kPeerTimeout,
  kStatsInterval,
  kControlTiming,
  kReconnectGrace,
  kMaxParticipants,
  kNoiseSuppression,
  kTalkMode,
  kVadSensitivity,
  kVadTail,
};

[[nodiscard]] ConfigError validate(const CoreConfig& config);

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_CONFIG_CORE_CONFIG_H_
