#include "config/core_config.h"

#include <cstddef>

#include "net/endpoint.h"

namespace voice_core {
namespace {

// Limits imposed by the protocol, by Opus or by Android, not tunables.
constexpr int kProtocolSampleRateHz = 16000;  // PROTOCOL.md: timestamps are 16 kHz samples
constexpr int kSupportedFrameMs[] = {10, 20, 40, 60};
constexpr std::size_t kMaxDisplayNameCharacters = 32;
constexpr uint16_t kMinUnprivilegedPort = 1024;
constexpr int kMaxDscp = 63;
constexpr int kMinOpusBitrateBps = 6000;
constexpr int kMaxOpusBitrateBps = 510000;
constexpr int kMaxPercent = 100;
constexpr int kMaxOpusComplexity = 10;
constexpr int kMaxJitterMs = 1000;
constexpr int kMaxAdaptHoldMs = 10000;
constexpr int kMinJitterWindowMs = 1000;
constexpr int kMaxJitterWindowMs = 60000;
constexpr int kMaxConcealmentMs = 1000;
constexpr int kMaxPlayoutBufferMs = 200;
constexpr int kMaxNetworkPollMs = 100;
constexpr int kMinIntervalMs = 100;
constexpr int kMaxIntervalMs = 10000;
constexpr int kMaxTimeoutMs = 60000;
constexpr int kMaxReconnectGraceMs = 600000;
constexpr int kMinParticipants = 2;
constexpr int kMaxParticipants = 8;
constexpr int kMaxVadTailMs = 2000;
constexpr unsigned char kUtf8ContinuationMask = 0xC0;
constexpr unsigned char kUtf8ContinuationBits = 0x80;

constexpr bool inRange(int value, int low, int high) noexcept { return value >= low && value <= high; }

// Counts UTF-8 code points by skipping continuation bytes (10xxxxxx).
std::size_t countCharacters(const std::string& text) noexcept {
  std::size_t characters = 0;
  for (const char byte : text) {
    if ((static_cast<unsigned char>(byte) & kUtf8ContinuationMask) != kUtf8ContinuationBits) {
      ++characters;
    }
  }
  return characters;
}

bool isValidHostIp(const std::string& text) noexcept {
  const std::optional<uint32_t> address = parseIpv4(text);
  return address.has_value() && isUnicast(*address);
}

bool isSupportedFrame(const CoreConfig& config) noexcept {
  // The upper bound (one second) also keeps the multiplication below from overflowing.
  if (config.frameSamples <= 0 || config.frameSamples > config.sampleRateHz ||
      (config.frameSamples * CoreConfig::kMsPerSecond) % config.sampleRateHz != 0) {
    return false;
  }
  const int frameMs = config.frameMs();
  for (const int supported : kSupportedFrameMs) {
    if (frameMs == supported) {
      return true;
    }
  }
  return false;
}

ConfigError validateSession(const CoreConfig& config) {
  if (config.role == Role::kClient) {
    if (!isValidHostIp(config.hostIp)) {
      return ConfigError::kHostIp;
    }
    if (config.echoMode) {
      return ConfigError::kEchoModeOnClient;
    }
  }
  const std::size_t characters = countCharacters(config.displayName);
  if (characters == 0 || characters > kMaxDisplayNameCharacters) {
    return ConfigError::kDisplayName;
  }
  if (config.controlPort < kMinUnprivilegedPort) {
    return ConfigError::kControlPort;
  }
  if (config.audioPort < kMinUnprivilegedPort) {
    return ConfigError::kAudioPort;
  }
  if (!inRange(config.audioDscp, 0, kMaxDscp)) {
    return ConfigError::kAudioDscp;
  }
  return ConfigError::kNone;
}

ConfigError validateCodec(const CoreConfig& config) {
  if (config.sampleRateHz != kProtocolSampleRateHz) {
    return ConfigError::kSampleRate;
  }
  if (!isSupportedFrame(config)) {
    return ConfigError::kFrameSamples;
  }
  if (!inRange(config.bitrateBps, kMinOpusBitrateBps, kMaxOpusBitrateBps)) {
    return ConfigError::kBitrate;
  }
  if (!inRange(config.expectedLossPct, 0, kMaxPercent)) {
    return ConfigError::kExpectedLoss;
  }
  if (!inRange(config.opusComplexity, 0, kMaxOpusComplexity)) {
    return ConfigError::kOpusComplexity;
  }
  return ConfigError::kNone;
}

ConfigError validateBuffers(const CoreConfig& config) {
  const int frameMs = config.frameMs();
  if (config.jitterMinMs < frameMs || config.jitterInitialMs < config.jitterMinMs ||
      config.jitterMaxMs < config.jitterInitialMs || config.jitterMaxMs > kMaxJitterMs) {
    return ConfigError::kJitterRange;
  }
  if (!inRange(config.jitterAdaptHoldMs, frameMs, kMaxAdaptHoldMs) ||
      !inRange(config.jitterWindowMs, kMinJitterWindowMs, kMaxJitterWindowMs)) {
    return ConfigError::kJitterAdaptation;
  }
  if (!inRange(config.concealmentMaxMs, 0, kMaxConcealmentMs)) {
    return ConfigError::kConcealment;
  }
  if (!inRange(config.devicePeriodMs, 1, frameMs) ||
      !inRange(config.playoutBufferMs, config.devicePeriodMs, kMaxPlayoutBufferMs) ||
      !inRange(config.mediaLoopPeriodMs, 1, config.devicePeriodMs) ||
      !inRange(config.networkPollMs, 1, kMaxNetworkPollMs)) {
    return ConfigError::kDeviceTiming;
  }
  return ConfigError::kNone;
}

ConfigError validateTiming(const CoreConfig& config) {
  if (!inRange(config.keepaliveIntervalMs, kMinIntervalMs, kMaxIntervalMs)) {
    return ConfigError::kKeepalive;
  }
  if (!inRange(config.peerTimeoutMs, config.keepaliveIntervalMs + 1, kMaxTimeoutMs)) {
    return ConfigError::kPeerTimeout;
  }
  if (!inRange(config.statsIntervalMs, kMinIntervalMs, kMaxIntervalMs)) {
    return ConfigError::kStatsInterval;
  }
  if (!inRange(config.controlPingIntervalMs, kMinIntervalMs, kMaxIntervalMs) ||
      !inRange(config.controlTimeoutMs, config.controlPingIntervalMs + 1, kMaxTimeoutMs)) {
    return ConfigError::kControlTiming;
  }
  if (!inRange(config.reconnectGraceMs, 0, kMaxReconnectGraceMs)) {
    return ConfigError::kReconnectGrace;
  }
  if (!inRange(config.maxParticipants, kMinParticipants, kMaxParticipants)) {
    return ConfigError::kMaxParticipants;
  }
  return ConfigError::kNone;
}

// The enums arrive from the C API as integers, so their range is checked too.
ConfigError validateVoice(const CoreConfig& config) {
  if (config.noiseSuppression > NoiseSuppression::kVeryHigh) {
    return ConfigError::kNoiseSuppression;
  }
  if (config.talkMode > TalkMode::kPushToTalk) {
    return ConfigError::kTalkMode;
  }
  if (config.vadSensitivity > VadSensitivity::kHigh) {
    return ConfigError::kVadSensitivity;
  }
  if (!inRange(config.vadTailMs, 0, kMaxVadTailMs)) {
    return ConfigError::kVadTail;
  }
  return ConfigError::kNone;
}

}  // namespace

ConfigError validate(const CoreConfig& config) {
  for (const auto check :
       {validateSession, validateCodec, validateBuffers, validateTiming, validateVoice}) {
    const ConfigError error = check(config);
    if (error != ConfigError::kNone) {
      return error;
    }
  }
  return ConfigError::kNone;
}

}  // namespace voice_core
